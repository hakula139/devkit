# ==================================================================================================
# Package-bound Library
# ==================================================================================================

{
  pkgs,
  git-hooks-nix,
  nushell,
}:

let
  lockedTool =
    runtimeInputs: runner: prepare: command:
    pkgs.writeShellApplication {
      inherit runtimeInputs;
      name = command;
      text = "exec ${runner} ${command} \"$@\"";
      passthru.prepare = pkgs.writeShellApplication (prepare // { inherit runtimeInputs; });
    };

  writeNuBin =
    name:
    pkgs.writers.makeScriptWriter {
      interpreter = "${pkgs.lib.getExe nushell} --no-config-file";
    } "/bin/${name}";

  actionlint = pkgs.callPackage ./packages/actionlint.nix { };

  nodeToolchain = {
    nodejs = pkgs.nodejs_26;
    pnpm = pkgs.pnpm_12;
  };

  nodeTool = lockedTool (builtins.attrValues nodeToolchain) "pnpm exec" {
    name = "pnpm-install";
    text = "exec pnpm install --frozen-lockfile";
  };

  uvTool = lockedTool [ pkgs.uv ] "uv run --locked" {
    name = "uv-sync";
    text = "exec uv sync --locked";
  };

  nu-check = writeNuBin "nu-check" ../src/nu-check.nu;
  nu-test = writeNuBin "nu-test" ../src/nu-test.nu;
in
{
  inherit
    nodeTool
    nodeToolchain
    nu-check
    nu-test
    nushell
    uvTool
    ;

  preCommit = import ./hooks.nix {
    inherit
      pkgs
      git-hooks-nix
      actionlint
      nodeTool
      nu-check
      uvTool
      ;
  };

  nuTests = import ./nu-test-check.nix { inherit pkgs nushell nu-test; };

  mkNuApplication = import ./mk-nu-application.nix { inherit pkgs nushell; };
}
