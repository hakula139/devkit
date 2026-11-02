# ==================================================================================================
# Node Hook Entry
# ==================================================================================================

{
  pkgs,
  command,
  nodejs ? pkgs.nodejs,
}:

pkgs.lib.getExe (
  pkgs.writeShellApplication {
    name = "node-${command}";
    runtimeInputs = [ nodejs ];
    text = ''
      if [ ! -d node_modules ]; then
        echo "node_modules is missing. Install the Node dependencies, then commit again." >&2
        exit 1
      fi
      exec node_modules/.bin/${command} "$@"
    '';
  }
)
