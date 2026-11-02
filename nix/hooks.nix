# ==================================================================================================
# Pre-commit Hooks
# ==================================================================================================

{
  git-hooks-nix,
}:

{
  pkgs,
  src,
  hooks ? { },
  devHooks ? { },
  checkHooks ? { },
  excludes ? [ "(^|/)fixtures/" ],
}:

let
  inherit (pkgs) lib;

  baseline = {
    actionlint.enable = true;
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
    editorconfig-checker.enable = true;
    end-of-file-fixer.enable = true;

    markdownlint-cli2 = {
      enable = true;
      description = "Lint Markdown with markdownlint-cli2.";
      entry = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2 --fix";
      files = "\\.md$";
    };

    nixfmt.enable = true;

    prettier = {
      enable = true;
      files = "\\.(json|jsonc|ya?ml)$";
    };

    shellcheck = {
      enable = true;
      types_or = [
        "sh"
        "bash"
        "dash"
        "ksh"
      ];
    };

    # `shfmt` reads `.editorconfig` only when the entry passes no formatting flag. Any flag
    # reverts it to tabs and ignores the `binary_next_line` and `switch_case_indent` keys.
    # `simplify` also strips the quotes inside `[[ ]]`.
    shfmt = {
      enable = true;
      settings = {
        language-dialect = null;
        simplify = false;
        indent = null;
        binary-next-line = false;
        case-indent = false;
      };
    };

    statix.enable = true;
    taplo.enable = true;

    trim-trailing-whitespace = {
      enable = true;
      # Preserve Markdown's two-trailing-space hard-break syntax.
      args = [ "--markdown-linebreak-ext=md" ];
    };
  };

  run =
    extraHooks: disabled:
    assert lib.assertMsg (builtins.hasAttr pkgs.stdenv.hostPlatform.system git-hooks-nix.lib)
      "git-hooks.nix does not support ${pkgs.stdenv.hostPlatform.system}";
    let
      merged = lib.recursiveUpdate (lib.recursiveUpdate baseline hooks) extraHooks;
      allHooks = lib.recursiveUpdate merged disabled;
    in
    git-hooks-nix.lib.${pkgs.stdenv.hostPlatform.system}.run {
      inherit src excludes;
      package = pkgs.prek;
      tools = import "${git-hooks-nix}/nix/call-tools.nix" pkgs;
      hooks = allHooks;
    };
in
{
  # `devHooks` may need a local environment such as `uv run --frozen pytest`, whereas
  # `check` runs in the Nix sandbox.
  dev = run devHooks { };

  # A dev-only replacement is lockfile-pinned or needs the working tree's environment, so the
  # check disables it even when `hooks` enables the nixpkgs counterpart under the same name.
  check = run checkHooks (
    lib.genAttrs (builtins.attrNames devHooks) (_: {
      enable = false;
    })
  );
}
