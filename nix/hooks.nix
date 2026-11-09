# ==================================================================================================
# Pre-commit Hooks
# ==================================================================================================

{
  pkgs,
  git-hooks-nix,
  actionlint,
  nu-check,
}:

{
  src,
  hooks ? { },
  devHooks ? { },
  excludes ? [ ],
}:

let
  inherit (pkgs) lib;

  # ------------------------------------------------------------------------------------------------
  # Formatter configuration
  # ------------------------------------------------------------------------------------------------
  json = pkgs.formats.json { };

  dprintConfig = json.generate "dprint.json" {
    markdown = {
      emphasisKind = "underscores";
      strongKind = "asterisks";
    };

    # Language plugins would also rewrite fenced examples inside Markdown.
    plugins = [ "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm" ];
  };

  # A project config stays checkout-relative, since Prettier resolves `overrides` globs from the
  # config file's directory.
  projectConfig = file: shared: if builtins.pathExists "${src}/${file}" then file else "${shared}";

  configEntry =
    hook: arguments:
    lib.concatStringsSep " " (
      [ (lib.getExe hook.package) ]
      ++ arguments
      ++ lib.optionals (hook.settings.configPath != "") [
        "--config"
        (lib.escapeShellArg hook.settings.configPath)
      ]
    );

  # ------------------------------------------------------------------------------------------------
  # Hook options
  # ------------------------------------------------------------------------------------------------
  configPathOptions =
    { hookModule, ... }:
    {
      options.hooks =
        lib.genAttrs
          [
            "markdownlint-cli2"
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

  # ------------------------------------------------------------------------------------------------
  # Hook defaults
  # ------------------------------------------------------------------------------------------------
  ruffHook = {
    require_serial = true;
    types = [ "file" ];
    types_or = [
      "python"
      "pyi"
      "jupyter"
    ];
  };

  baseline =
    { config, ... }:
    {
      excludes = [
        "(^|/)fixtures/"
      ];

      hooks = lib.mapAttrsRecursiveCond (attrs: !lib.isDerivation attrs) (_: lib.mkOverride 900) {
        actionlint = {
          package = actionlint;
        };

        check-added-large-files.enable = true;
        check-merge-conflicts.enable = true;

        cspell = {
          args = [
            "--no-progress"
            "--no-must-find-files"
          ];
        };

        doctoc = {
          package = pkgs.doctoc;
          entry = lib.getExe config.hooks.doctoc.package;
          args = [
            "--update-only"
            "--notitle"
            "--maxlevel=3"
          ];
          files = "\\.md$";
        };

        dprint = {
          package = pkgs.dprint;
          entry = "${lib.getExe config.hooks.dprint.package} fmt";
          args = [
            "--config=${dprintConfig}"
            "--allow-no-files"
          ];
          files = "\\.md$";
        };

        end-of-file-fixer.enable = true;

        markdownlint-cli2 = {
          package = pkgs.markdownlint-cli2;
          entry = configEntry config.hooks.markdownlint-cli2 [
            "--fix"
            "--no-globs"
          ];
          files = "\\.md$";
          settings.configPath = "${../.markdownlint-cli2.jsonc}";
        };

        nu-check = {
          package = nu-check;
          entry = lib.getExe config.hooks.nu-check.package;
        };

        # Markdown stays out of Prettier, which drops the blank line before nested items.
        prettier = {
          files = "\\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|json|jsonc|ya?ml)$";
          settings = {
            configPath = projectConfig ".prettierrc.json" ../.prettierrc.json;
            no-editorconfig = true;
          };
        };

        # Mirrors astral-sh/ruff-pre-commit, except that dprint owns Markdown.
        ruff = ruffHook // {
          entry = lib.concatStringsSep " " [
            (lib.getExe config.hooks.ruff.package)
            "check"
            "--fix"
            "--force-exclude"
          ];
        };

        ruff-format = ruffHook // {
          entry = lib.concatStringsSep " " [
            (lib.getExe config.hooks.ruff-format.package)
            "format"
            "--force-exclude"
          ];
        };

        shellcheck = {
          exclude_types = [
            "zsh"
          ];
        };

        # Formatting flags disable shfmt's EditorConfig settings.
        shfmt = {
          settings = {
            binary-next-line = true;
            case-indent = true;
            indent = 2;
            language-dialect = null;
            simplify = false;
          };
        };

        sort-file-contents = {
          files = "^\\.cspell/words\\.txt$";
          settings.ignore-case = true;
        };

        taplo = {
          entry = configEntry config.hooks.taplo [ "fmt" ];
          settings.configPath = projectConfig ".taplo.toml" ../.taplo.toml;
        };

        trim-trailing-whitespace = {
          enable = true;
          args = [ "--markdown-linebreak-ext=md" ];
        };
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Hook evaluation
  # ------------------------------------------------------------------------------------------------
  # Mirrors git-hooks.nix's own overlay, so the hooks build from the consumer's package set.
  gitHooksRun = pkgs.callPackage "${git-hooks-nix}/nix/run.nix" {
    tools = import "${git-hooks-nix}/nix/call-tools.nix" pkgs;
    isFlakes = true;
  };

  run =
    modules:
    gitHooksRun {
      inherit src;
      package = pkgs.prek;
      imports = [
        configPathOptions
        baseline
        { inherit hooks excludes; }
      ]
      ++ modules;
    };

  dev = run [ { hooks = devHooks; } ];

  check = run [
    { hooks = lib.mapAttrs (_: _: { enable = lib.mkForce false; }) devHooks; }
    # lychee loads CA certificates even with `--offline`, which the check sandbox lacks. The dev
    # shell omits them, since cacert's setup hook would replace the host's NIX_SSL_CERT_FILE.
    { hooks.lychee.extraPackages = [ pkgs.cacert ]; }
  ];

  # ------------------------------------------------------------------------------------------------
  # Hook installation
  # ------------------------------------------------------------------------------------------------
  flock = lib.getExe pkgs.flock;
  git = lib.getExe dev.config.gitPackage;

  hookTypes = lib.unique (
    map (
      stage:
      if
        lib.elem stage [
          "commit"
          "merge-commit"
          "push"
        ]
      then
        "pre-${stage}"
      else
        stage
    ) (lib.remove "manual" dev.config.installStages)
  );
in
{
  inherit check;

  shell = pkgs.mkShell {
    # Listed directly, the hook packages' setup hooks would set the consumer's PYTHONPATH.
    # A colliding executable keeps the first package's, matching the PATH order of a plain list.
    packages = [
      (pkgs.buildEnv {
        name = "pre-commit-hook-tools";
        paths = dev.enabledPackages;
        pathsToLink = [ "/bin" ];
        ignoreCollisions = true;
      })
      dev.config.package
    ];

    shellHook = ''
      if top=$(${git} rev-parse --show-toplevel 2>/dev/null); then
        # Linked worktrees share hooks, so their common Git directory owns the install lock.
        common=$(
          ${git} rev-parse \
            --path-format=absolute \
            --git-common-dir
        )

        (
          set -e
          ${flock} 9

          # Keep hook tools alive through the config's GC root.
          # Nix refuses to replace an existing regular file.
          ${lib.getExe' pkgs.nix "nix-store"} \
            --add-root "$top/${dev.config.configPath}" \
            --indirect \
            --realise ${dev.config.configFile}

          # Refresh shims even with unchanged config, preserving core.hooksPath.
          # Empty stage arguments would make prek install pre-commit by default.
          ${lib.optionalString (hookTypes != [ ]) ''
            ${lib.getExe dev.config.package} install \
              --config ${lib.escapeShellArg dev.config.configPath} \
              ${lib.escapeShellArgs (
                lib.concatMap (hookType: [
                  "--hook-type"
                  hookType
                ]) hookTypes
              )}
          ''}
        ) 9>"$common/git-hooks.lock"
      fi
    '';
  };
}
