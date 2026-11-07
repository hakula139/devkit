# ==================================================================================================
# Pre-commit Hooks
# ==================================================================================================

{
  pkgs,
  git-hooks-nix,
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

  dprintConfig = (pkgs.formats.json { }).generate "dprint.json" {
    markdown = {
      emphasisKind = "underscores";
      strongKind = "asterisks";
    };

    # Language plugins would also rewrite fenced examples inside Markdown.
    plugins = [ "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm" ];
  };

  taploConfig = lib.findFirst builtins.pathExists (pkgs.writeText "taplo.toml" "") [
    (src + "/.taplo.toml")
    (src + "/taplo.toml")
  ];

  prettierConfig =
    lib.findFirst builtins.pathExists ((pkgs.formats.json { }).generate "prettier.json" { })
      [
        (src + "/.prettierrc.json")
        (src + "/.prettierrc")
      ];

  baseline =
    { config, ... }:
    {
      excludes = [
        "(^|/)fixtures/"
      ];

      hooks = lib.mapAttrsRecursiveCond (attrs: !lib.isDerivation attrs) (_: lib.mkOverride 900) {
        actionlint = {
          enable = true;
          package = pkgs.actionlint.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              (pkgs.fetchpatch {
                url = "https://github.com/rhysd/actionlint/commit/644076a59742c2d1540ebd4686eab3c308f0e562.patch";
                hash = "sha256-Lpd7CTkLbzgvAZV2H8G4GTUoPNDCK7PiW3A40+cquUk=";
              })
            ];
          });
          # actionlint's v3 metadata predates the client-id input (rhysd/actionlint#669).
          args = [
            "-ignore"
            ''(missing input "app-id" which is required by action|input "client-id" is not defined in action) "actions/create-github-app-token@v3"''
          ];
        };
        check-added-large-files.enable = true;
        check-merge-conflicts.enable = true;
        check-yaml.enable = true;

        cspell = {
          enable = true;
          args = [
            "--no-progress"
            "--no-must-find-files"
          ];
        };

        deadnix.enable = true;

        doctoc = {
          enable = true;
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
          enable = true;
          package = pkgs.dprint;
          entry = "${lib.getExe config.hooks.dprint.package} fmt";
          args = [
            "--config=${dprintConfig}"
            "--allow-no-files"
          ];
          files = "\\.md$";
        };

        editorconfig-checker.enable = true;
        end-of-file-fixer.enable = true;

        markdownlint-cli2 = {
          enable = true;
          package = pkgs.markdownlint-cli2;
          entry = lib.getExe config.hooks.markdownlint-cli2.package;
          args = [ "--fix" ];
          files = "\\.md$";
        };

        nixfmt.enable = true;

        nu-check = {
          package = nu-check;
          entry = lib.getExe config.hooks.nu-check.package;
        };

        # Markdown stays out of Prettier, which drops the blank line before nested items.
        prettier = {
          enable = true;
          files = "\\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|json|jsonc|ya?ml)$";
          settings = {
            configPath = "${prettierConfig}";
            no-editorconfig = true;
          };
        };

        shellcheck = {
          enable = true;
          exclude_types = [
            "zsh"
          ];
        };

        # Formatting flags disable shfmt's EditorConfig settings.
        shfmt = {
          enable = true;
          settings = {
            language-dialect = null;
            simplify = false;
          };
        };

        sort-file-contents = {
          enable = true;
          files = "^\\.cspell/words\\.txt$";
          settings.ignore-case = true;
        };

        statix.enable = true;
        taplo = {
          enable = true;
          args = [
            "--no-auto-config"
            "--config=${taploConfig}"
          ];
        };

        trim-trailing-whitespace = {
          enable = true;
          args = [ "--markdown-linebreak-ext=md" ];
        };
      };
    };

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

  cmp = lib.getExe' pkgs.diffutils "cmp";
  flock = lib.getExe pkgs.flock;
  git = lib.getExe dev.config.gitPackage;
  hookTypes = lib.unique (
    map
      (
        stage:
        if
          builtins.elem stage [
            "commit"
            "merge-commit"
            "push"
          ]
        then
          "pre-${stage}"
        else
          stage
      )
      (
        lib.remove "manual" (
          if dev.config.installStages == [ ] then [ "pre-commit" ] else dev.config.installStages
        )
      )
  );
in
{
  inherit check;

  shell = pkgs.mkShell {
    packages = dev.enabledPackages ++ [
      dev.config.package
    ];

    # Use shared hooks to avoid the relative path bug in linked worktrees (git-hooks.nix#688).
    # Serialize installation, and leave sibling repositories that borrow this shell untouched.
    shellHook = ''
      unset PYTHONPATH
      if top=$(${git} rev-parse --show-toplevel 2>/dev/null) &&
        ${cmp} -s ${src + "/flake.nix"} "$top/flake.nix"; then
        common=$(
          ${git} rev-parse \
            --path-format=absolute \
            --git-common-dir
        )
        (
          ${flock} 9
          ${git} config --local --unset-all core.hooksPath || true
          # pre-commit recognizes its generated hooks and restores custom legacy hooks itself.
          ${lib.optionalString (hookTypes != [ ]) ''
            ${lib.getExe pkgs.pre-commit} uninstall ${
              lib.escapeShellArgs (
                lib.concatMap (hookType: [
                  "--hook-type"
                  hookType
                ]) hookTypes
              )
            }
          ''}
          ${dev.config.installationScript}
          ${lib.optionalString (hookTypes != [ ]) ''
            if [ "$(readlink "$top/${dev.config.configPath}")" = "${dev.config.configFile}" ]; then
              ${lib.concatMapStringsSep "\n" (hookType: ''
                ${lib.getExe dev.config.package} install \
                  --config ${lib.escapeShellArg dev.config.configPath} \
                  --hook-type ${lib.escapeShellArg hookType}
              '') hookTypes}
            fi
          ''}
        ) 9>"$common/git-hooks.lock"
      fi
    '';
  };
}
