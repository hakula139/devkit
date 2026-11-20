# ==================================================================================================
# Hook Options
# ==================================================================================================

{
  lib,
}:

{
  hookOptions =
    { hookModule, ... }:
    {
      options.hooks =
        lib.genAttrs
          [
            "markdownlint-cli2"
            "ruff"
            "ruff-format"
            "taplo"
          ]
          (
            name:
            lib.mkOption {
              description = "${name} hook";
              type = lib.types.submodule {
                imports = [ hookModule ];
                options.settings.configPath = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = ''
                    Configuration file path, relative to the checkout root or absolute.
                    An empty string passes no `--config`, so ${name} finds its own configuration.
                  '';
                };
              };
            }
          )
        // {
          nu-check = lib.mkOption {
            type = lib.types.submodule {
              options.settings.libDirs = lib.mkOption {
                type = lib.types.listOf lib.types.path;
                default = [ ];
                description = "Module directories added to `NU_LIB_DIRS` when checking Nushell files.";
              };
            };
          };
        };
    };

  configEntry =
    hook: command:
    lib.escapeShellArgs (
      [ (lib.getExe hook.package) ]
      ++ command
      ++ lib.optionals (hook.settings.configPath != "") [
        "--config"
        hook.settings.configPath
      ]
    );

  nuCheckEntry =
    hook:
    let
      exe = lib.getExe hook.package;
    in
    if hook.settings.libDirs == [ ] then
      exe
    else
      lib.escapeShellArgs [
        "env"
        "NU_LIB_DIRS=${lib.concatMapStringsSep ":" (dir: "${dir}") hook.settings.libDirs}"
        exe
      ];
}
