# ==================================================================================================
# Pre-commit Hooks
# ==================================================================================================

{
  pkgs,
  git-hooks-nix,
  actionlint,
  nodeTool,
  nu-check,
  uvTool,
}:

{
  src,
  hooks ? { },
  excludes ? [ ],
}:

let
  inherit (pkgs) lib;

  # ------------------------------------------------------------------------------------------------
  # Formatter configuration
  # ------------------------------------------------------------------------------------------------
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

  json = pkgs.formats.json { };

  dprintConfig = json.generate "dprint.json" {
    markdown = {
      emphasisKind = "underscores";
      strongKind = "asterisks";
    };

    # Language plugins would also rewrite fenced examples inside Markdown.
    plugins = [ "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm" ];
  };

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

        clippy = {
          entry = lib.concatStringsSep " " [
            (lib.getExe' config.hooks.clippy.package "cargo-clippy")
            "clippy"
            "--locked"
            "--all-targets"
            "--config"
            (lib.escapeShellArg ''build.warnings="deny"'')
          ];
        };

        cspell = {
          entry = lib.concatStringsSep " " [
            (lib.getExe config.hooks.cspell.package)
            "--no-progress"
            "--no-must-find-files"
          ];
        };

        doctoc = {
          package = pkgs.doctoc;
          entry = lib.concatStringsSep " " [
            (lib.getExe config.hooks.doctoc.package)
            "--update-only"
            "--notitle"
            "--maxlevel=3"
          ];
          files = "\\.md$";
        };

        dprint = {
          package = pkgs.dprint;
          entry = lib.concatStringsSep " " [
            (lib.getExe config.hooks.dprint.package)
            "fmt"
            "--config=${dprintConfig}"
            "--allow-no-files"
          ];
          files = "\\.md$";
        };

        end-of-file-fixer.enable = true;

        eslint = {
          package = nodeTool "eslint";
          entry = lib.concatStringsSep " " [
            (lib.getExe config.hooks.eslint.package)
            "--fix"
            "--no-warn-ignored"
            "--max-warnings=0"
          ];
          files = "\\.(js|jsx|mjs|cjs|ts|tsx|mts|cts)$";
          require_serial = true;
        };

        markdownlint-cli2 = {
          package = pkgs.markdownlint-cli2;
          entry = configEntry config.hooks.markdownlint-cli2 [
            "--fix"
            "--no-globs"
          ];
          files = "\\.md$";
          settings.configPath = "${../.markdownlint-cli2.jsonc}";
        };

        mypy = {
          package = uvTool "mypy";
          entry = lib.getExe config.hooks.mypy.package;
          files = "";
          pass_filenames = false;
          types_or = [
            "python"
            "pyi"
          ];
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
          entry = configEntry config.hooks.ruff [
            "check"
            "--fix"
            "--force-exclude"
          ];
        };

        ruff-format = ruffHook // {
          entry = configEntry config.hooks.ruff-format [
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
          entry = lib.concatStringsSep " " [
            (lib.getExe' config.hooks.trim-trailing-whitespace.package "trailing-whitespace-fixer")
            "--markdown-linebreak-ext=md"
          ];
        };

        tsc = {
          package = nodeTool "tsc";
          entry = lib.concatStringsSep " " [
            (lib.getExe config.hooks.tsc.package)
            "--noEmit"
          ];
          files = "\\.(ts|tsx|mts|cts)$";
          pass_filenames = false;
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

  hooksRun = gitHooksRun {
    inherit src;
    package = pkgs.prek;
    imports = [
      configPathOptions
      baseline
      { inherit hooks excludes; }
    ];
  };

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
    ) (lib.remove "manual" hooksRun.config.installStages)
  );

  # ------------------------------------------------------------------------------------------------
  # Hook runner
  # ------------------------------------------------------------------------------------------------
  prepares = lib.unique (lib.catAttrs "prepare" hooksRun.enabledPackages);

  runHooks = pkgs.writeShellApplication {
    name = "run-hooks";
    runtimeInputs = [
      hooksRun.config.package
      hooksRun.config.gitPackage
    ];
    text = ''
      cd "$(git rev-parse --show-toplevel)"
      ${lib.concatMapStrings (prepare: "${lib.getExe prepare}\n") prepares}
      status=0
      for stage in ${lib.escapeShellArgs hookTypes}; do
        prek run \
          --config ${lib.escapeShellArg hooksRun.config.configPath} \
          --stage "$stage" \
          --all-files \
          --show-diff-on-failure \
          "$@" \
          || status=1
      done
      exit "$status"
    '';
  };

  # ------------------------------------------------------------------------------------------------
  # Hook installation
  # ------------------------------------------------------------------------------------------------
  flock = lib.getExe pkgs.flock;
  git = lib.getExe hooksRun.config.gitPackage;
in
pkgs.mkShell {
  # Listed directly, the hook packages' setup hooks would set the consumer's PYTHONPATH.
  # A colliding executable keeps the first package's, matching the PATH order of a plain list.
  packages = [
    (pkgs.buildEnv {
      name = "pre-commit-hook-tools";
      paths = hooksRun.enabledPackages;
      pathsToLink = [ "/bin" ];
      ignoreCollisions = true;
    })
    runHooks
    hooksRun.config.package
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
          --add-root "$top/${hooksRun.config.configPath}" \
          --indirect \
          --realise ${hooksRun.config.configFile}

        # Refresh shims even with unchanged config, preserving core.hooksPath.
        # Empty stage arguments would make prek install pre-commit by default.
        ${lib.optionalString (hookTypes != [ ]) ''
          ${lib.getExe hooksRun.config.package} install \
            --config ${lib.escapeShellArg hooksRun.config.configPath} \
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
}
