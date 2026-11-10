# ==================================================================================================
# Package-bound Library
# ==================================================================================================

{
  pkgs,
  git-hooks-nix,
  nushell,
  ruff,
  uv,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Locked tools
  # ------------------------------------------------------------------------------------------------
  lockedTool =
    runtimeInputs: runner: prepare: command:
    pkgs.writeShellApplication {
      inherit runtimeInputs;
      name = command;
      text = "exec ${runner} ${command} \"$@\"";
      passthru.prepare = pkgs.writeShellApplication (prepare // { inherit runtimeInputs; });
    };

  nodeToolchain = {
    nodejs = pkgs.nodejs_26;
    pnpm = pkgs.pnpm_12;
  };

  nodeTool = lockedTool (builtins.attrValues nodeToolchain) "pnpm exec" {
    name = "pnpm-install";
    text = "exec pnpm install --frozen-lockfile";
  };

  uvToolchain = {
    inherit uv;
  };

  uvTool = lockedTool (builtins.attrValues uvToolchain) "uv run --locked" {
    name = "uv-sync";
    text = "exec uv sync --locked";
  };

  # ------------------------------------------------------------------------------------------------
  # Nushell tools
  # ------------------------------------------------------------------------------------------------
  mkNuApplication = import ./mk-nu-application.nix { inherit pkgs nushell; };
  writeNuApplication = import ./write-nu-application.nix { inherit pkgs nushell; };

  writeNuBin =
    name: script:
    writeNuApplication {
      inherit name;
      text = builtins.readFile script;
    };

  nu-check = writeNuBin "nu-check" ../src/nu-check.nu;
  nu-test = writeNuBin "nu-test" ../src/nu-test.nu;

  nuTests = import ./nu-test-check.nix { inherit pkgs nushell nu-test; };

  # ------------------------------------------------------------------------------------------------
  # Pre-commit hooks
  # ------------------------------------------------------------------------------------------------
  actionlint = pkgs.callPackage ./packages/actionlint.nix { };

  preCommit = import ./hooks {
    inherit
      pkgs
      git-hooks-nix
      actionlint
      nodeTool
      nu-check
      ruff
      uvTool
      ;
  };
in
{
  inherit
    mkNuApplication
    nodeTool
    nodeToolchain
    nu-check
    nu-test
    nuTests
    nushell
    preCommit
    uvTool
    uvToolchain
    writeNuApplication
    ;
}
