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

  taploConfig =
    let
      configPath = "${src}/.taplo.toml";
    in
    if builtins.pathExists configPath then configPath else pkgs.writeText "taplo.toml" "";

  # ------------------------------------------------------------------------------------------------
  # Hook defaults
  # ------------------------------------------------------------------------------------------------
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
          entry = lib.getExe config.hooks.markdownlint-cli2.package;
          args = [
            "--config"
            "${../.markdownlint-cli2.jsonc}"
            "--fix"
            "--no-globs"
          ];
          files = "\\.md$";
        };

        nu-check = {
          package = nu-check;
          entry = lib.getExe config.hooks.nu-check.package;
        };

        # Markdown stays out of Prettier, which drops the blank line before nested items.
        prettier = {
          files = "\\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|json|jsonc|ya?ml)$";
          settings = {
            configPath =
              let
                configPath = "${src}/.prettierrc.json";
              in
              if builtins.pathExists configPath then configPath else "${../.prettierrc.json}";
            no-config = config.hooks.prettier.settings.configPath == "";
            no-editorconfig = true;
          };
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
          args = [ "--config=${taploConfig}" ];
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
        baseline
        { inherit hooks excludes; }
      ]
      ++ modules;
    };

  dev = run [ { hooks = devHooks; } ];
  check = run [ { hooks = lib.mapAttrs (_: _: { enable = lib.mkForce false; }) devHooks; } ];

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
