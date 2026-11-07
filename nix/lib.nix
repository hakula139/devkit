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
    runtimeInputs: runner: command:
    pkgs.writeShellApplication {
      inherit runtimeInputs;
      name = command;
      text = "exec ${runner} ${command} \"$@\"";
    };

  writeNuBin =
    name:
    pkgs.writers.makeScriptWriter {
      interpreter = "${pkgs.lib.getExe nushell} --no-config-file";
    } "/bin/${name}";

  actionlint = pkgs.callPackage ../packages/actionlint { };
  nu-check = writeNuBin "nu-check" ./nu-check.nu;
  nu-test = writeNuBin "nu-test" ./nu-test.nu;
in
{
  inherit nu-check nu-test nushell;

  preCommit = import ./hooks.nix {
    inherit
      pkgs
      git-hooks-nix
      actionlint
      nu-check
      ;
  };

  nodeTool = lockedTool [
    pkgs.nodejs_26
    pkgs.pnpm_12
  ] "pnpm exec";

  uvTool = lockedTool [
    pkgs.uv
  ] "uv run --locked";

  nuTests = import ./nu-test-check.nix { inherit pkgs nushell nu-test; };

  mkNuApplication = import ./mk-nu-application.nix { inherit pkgs nushell; };
}
