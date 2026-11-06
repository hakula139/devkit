# ==================================================================================================
# Package-bound Library
# ==================================================================================================

{
  pkgs,
  git-hooks-nix,
}:

let
  lockedTool =
    runtimeInputs: runner: command:
    pkgs.writeShellApplication {
      inherit runtimeInputs;
      name = command;
      text = "exec ${runner} ${command} \"$@\"";
    };
in
{
  preCommit = import ./hooks.nix { inherit pkgs git-hooks-nix; };
  nodeTool = lockedTool [
    pkgs.nodejs_26
    pkgs.pnpm_12
  ] "pnpm exec";
  uvTool = lockedTool [
    pkgs.uv
  ] "uv run --locked";
}
