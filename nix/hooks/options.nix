# ==================================================================================================
# Hook Options
# ==================================================================================================

{
  lib,
}:

{
  configPathOptions =
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
          );
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
}
