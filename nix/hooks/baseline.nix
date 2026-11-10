# ==================================================================================================
# Baseline Hooks
# ==================================================================================================

{
  pkgs,
  src,
  actionlint,
  configEntry,
  nodeTool,
  nu-check,
  uvTool,
}:

let
  inherit (pkgs) lib;

  # ------------------------------------------------------------------------------------------------
  # Formatter configuration
  # ------------------------------------------------------------------------------------------------
  dprintConfig = pkgs.writers.writeJSON "dprint.json" {
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

  # ------------------------------------------------------------------------------------------------
  # Shared hook settings
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

  # ------------------------------------------------------------------------------------------------
  # Definition priority
  # ------------------------------------------------------------------------------------------------
  # git-hooks.nix defines its hooks with `mkDefault`, so baseline values sit between those and a
  # consumer's definitions. `args` and `excludes` concatenate, with a consumer's list last.
  baselinePriority =
    path: value:
    if
      lib.elem (lib.last path) [
        "args"
        "excludes"
      ]
    then
      lib.mkBefore value
    else
      lib.mkOverride 900 value;
in
{ config, ... }:
{
  excludes = [
    "(^|/)fixtures/"
  ];

  hooks = lib.mapAttrsRecursiveCond (attrs: !lib.isDerivation attrs) baselinePriority {
    # ----------------------------------------------------------------------------------------------
    # General
    # ----------------------------------------------------------------------------------------------
    check-added-large-files.enable = true;
    check-merge-conflicts.enable = true;

    cspell = {
      enable = true;
      args = [
        "--no-progress"
        "--no-must-find-files"
      ];
    };

    editorconfig-checker.enable = true;
    end-of-file-fixer.enable = true;

    sort-file-contents = {
      enable = true;
      files = "^\\.cspell/words\\.txt$";
      settings.ignore-case = true;
    };

    trim-trailing-whitespace = {
      enable = true;
      args = [
        "--markdown-linebreak-ext=md"
      ];
    };

    # ----------------------------------------------------------------------------------------------
    # GitHub Actions
    # ----------------------------------------------------------------------------------------------
    actionlint = {
      enable = true;
      package = actionlint;
    };

    # ----------------------------------------------------------------------------------------------
    # JavaScript / TypeScript
    # ----------------------------------------------------------------------------------------------
    eslint = {
      package = nodeTool "eslint";
      args = [
        "--no-warn-ignored"
        "--max-warnings=0"
      ];
      require_serial = true;
      settings.extensions = "\\.(js|jsx|mjs|cjs|ts|tsx|mts|cts)$";
    };

    tsc = {
      package = nodeTool "tsc";
      entry = lib.getExe config.hooks.tsc.package;
      args = [
        "--noEmit"
      ];
      files = "\\.(ts|tsx|mts|cts)$";
      pass_filenames = false;
    };

    # ----------------------------------------------------------------------------------------------
    # Markdown
    # ----------------------------------------------------------------------------------------------
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
      enable = true;
      package = pkgs.dprint;
      entry = "${lib.getExe config.hooks.dprint.package} fmt";
      args = [
        "--config=${dprintConfig}"
        "--allow-no-files"
      ];
      files = "\\.md$";
    };

    markdownlint-cli2 = {
      enable = true;
      package = pkgs.markdownlint-cli2;
      entry = configEntry config.hooks.markdownlint-cli2 [ ];
      args = [
        "--fix"
        "--no-globs"
      ];
      files = "\\.md$";
      settings.configPath = "${../../.markdownlint-cli2.jsonc}";
    };

    # ----------------------------------------------------------------------------------------------
    # Nix
    # ----------------------------------------------------------------------------------------------
    deadnix.enable = true;
    nixfmt.enable = true;
    statix.enable = true;

    # ----------------------------------------------------------------------------------------------
    # Nushell
    # ----------------------------------------------------------------------------------------------
    nu-check = {
      package = nu-check;
      entry = lib.getExe config.hooks.nu-check.package;
    };

    # ----------------------------------------------------------------------------------------------
    # Python
    # ----------------------------------------------------------------------------------------------
    mypy = {
      package = uvTool "mypy";
      files = "";
      pass_filenames = false;
      types_or = [
        "python"
        "pyi"
      ];
    };

    # Mirrors astral-sh/ruff-pre-commit, except that dprint owns Markdown.
    ruff = ruffHook // {
      entry = configEntry config.hooks.ruff [
        "check"
        "--fix"
      ];
      args = [
        "--force-exclude"
      ];
    };

    # Upstream runs `hooks.ruff.package` for ruff-format.
    ruff-format = ruffHook // {
      entry = configEntry config.hooks.ruff-format [ "format" ];
      args = [
        "--force-exclude"
      ];
    };

    # ----------------------------------------------------------------------------------------------
    # Rust
    # ----------------------------------------------------------------------------------------------
    clippy = {
      settings = {
        denyWarnings = true;
        extraArgs = "--locked --all-targets";
        offline = false;
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Shell
    # ----------------------------------------------------------------------------------------------
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

    # ----------------------------------------------------------------------------------------------
    # TOML
    # ----------------------------------------------------------------------------------------------
    taplo = {
      entry = configEntry config.hooks.taplo [ "fmt" ];
      settings.configPath = projectConfig ".taplo.toml" ../../.taplo.toml;
    };

    # ----------------------------------------------------------------------------------------------
    # Web formats
    # ----------------------------------------------------------------------------------------------
    # Markdown stays out of Prettier, which drops the blank line before nested items.
    prettier = {
      files = "\\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|json|jsonc|ya?ml)$";
      excludes = [
        "(^|/)pnpm-lock\\.yaml$"
      ];
      settings = {
        configPath = projectConfig ".prettierrc.json" ../../.prettierrc.json;
        no-editorconfig = true;
      };
    };
  };
}
