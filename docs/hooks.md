# Hooks

## Set up the dev shell

Add `preCommit` to `inputsFrom` as shown in [Nix flake](flake.md). The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Enter the dev shell from the checkout where you intend to install the hooks. Its configuration path must either be absent or point into the Nix store through a symlink. Installing prek's shims replaces existing hooks, including the targets of symlinked hooks.

Hook installation reports on stderr so callers of `nix develop -c <cmd>` can read the command's output from stdout. Keep stdout clear in the repository's own `shellHook` for the same reason.

As in CI, run `run-hooks` separately from `nix flake check`. The hook runner prepares dependencies for enabled lockfile-pinned tools, then checks tracked files across the pre-commit, pre-merge-commit, and pre-push stages. To run a subset, pass hook IDs as in `nix develop -c run-hooks cspell`.

```bash
nix develop -c run-hooks
```

## Enable hooks

The baseline enables file hygiene, spelling, EditorConfig, Markdown formatting and linting, Nix checks, YAML syntax, and GitHub Actions linting. Use `hooks.<name>.enable` to turn off a default or opt into a project-specific check.

| Project files             | Hooks to enable               | Scope                                                                       |
| ------------------------- | ----------------------------- | --------------------------------------------------------------------------- |
| Documentation             | `doctoc`, `lychee`            | Maintain marked tables of contents or check links                           |
| JavaScript and TypeScript | `eslint`, `tsc`               | Lint selected scripts or type-check the project                             |
| Web formats and TOML      | `prettier`, `taplo`           | Format JS, TS, CSS, JSON, JSONC, and YAML with Prettier, or TOML with Taplo |
| Nushell                   | `nu-check`                    | Check scripts with the project's module search paths                        |
| Python                    | `mypy`, `ruff`, `ruff-format` | Type-check, lint, or format                                                 |
| Rust                      | `clippy`, `rustfmt`           | Lint or format with the project's toolchain                                 |
| Shell                     | `shellcheck`, `shfmt`         | Lint or format shell scripts                                                |

ESLint and clippy treat warnings as errors because prek hides the output of a passing hook. See the [baseline](../nix/hooks/baseline.nix) for individual defaults and the [upstream hook definitions](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) for settings.

## Configure a hook

### Override the baseline

A definition under `hooks` generally replaces the baseline value. The `args` and `excludes` lists append by default, so wrap them in `lib.mkForce` when you need to replace them.

```nix
preCommit = dk.preCommit {
  src = ./.;
  hooks = {
    prettier = {
      enable = true;
      files = "\\.(json|ya?ml)$";
    };
    trim-trailing-whitespace.excludes = [
      "\\.patch$"
    ];
    cspell.args = lib.mkForce [
      "--no-progress"
    ];
  };
};
```

### Use a project configuration file

Prettier, Taplo, and markdownlint-cli2 use devkit's shared [Prettier style](../.prettierrc.json), [Taplo formatting](../.taplo.toml), and [markdownlint rules](../.markdownlint-cli2.jsonc). A `.prettierrc.json` or `.taplo.toml` at the source root replaces the shared file once the dev shell is re-entered, and a project `.markdownlint-cli2.jsonc` overrides individual shared rules.

Use basenames in the shared Prettier configuration's `overrides`, since Prettier resolves those globs from the configuration's Nix store directory.

Set `hooks.<name>.settings.configPath` to point markdownlint-cli2, Prettier, Ruff, or Taplo at another file, or to `""` to let the tool find its own. A `.markdownlint-cli2.jsonc` that loads relative `customRules` or `markdownItPlugins` needs `configPath = ".markdownlint-cli2.jsonc"`, which drops the shared rules.

### Add a spelling dictionary

Name the project dictionary in `cspell.json`. The `sort-file-contents` hook sorts `.cspell/words.txt` by default, so set `hooks.sort-file-contents.files` if you keep the dictionary elsewhere.

### Generate Markdown tables of contents

doctoc fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.

### Format Markdown

Let dprint format Markdown so it preserves indentation and blank lines in fenced examples and leaves embedded HTML intact. It formats every file that prek selects, including tracked Markdown files that match Git ignore rules. Keep the Markdown override in `.editorconfig` so editors preserve two-space hard line breaks.

### Check EditorConfig properties

Because EditorConfig has no include mechanism and editors use it outside the dev shell, check in a copy of the shared `.editorconfig` and add language-specific sections that match the repository's formatters. The Nushell section also sets the indentation the checker enforces, since no hook formats Nushell.

Exclude binary payloads that the checker treats as text through `hooks.editorconfig-checker.excludes`.

### Check Nushell files

Set `hooks.nu-check.settings.libDirs` to any module directories that scripts `use` by name, as [Share modules](nushell.md#share-modules) describes.

### Type-check Python

mypy checks the `files` that `[tool.mypy]` names, whichever files changed.

### Lint and format Python

To run both Ruff hooks at the version in `uv.lock`, add `ruff` to the `dev` dependency group and set the package once.

```nix
hooks.ruff.package = dk.uvTool "ruff";
```

### Lint and format Rust

Point clippy and rustfmt at the repository's toolchain so the hooks use the same compiler and formatter as local development.

```nix
hooks = {
  clippy.packageOverrides = {
    cargo = rustToolchain;
    clippy = rustToolchain;
  };
  rustfmt.packageOverrides = {
    cargo = rustToolchain;
    rustfmt = rustToolchain;
  };
};
```

Set Cargo flags in `hooks.clippy.settings` and lint levels in `Cargo.toml` `[lints]`. clippy runs with `--locked --all-targets`, so commit `Cargo.lock` or replace `settings.extraArgs`.

### Check shell files

Start the repository's `.envrc` with a shell directive so shellcheck can lint it without a shebang.

```bash
# shellcheck shell=bash
```

## Run a lockfile-pinned tool

ESLint and TypeScript already run from the project's pnpm lockfile, and mypy runs from its uv lockfile. Use `dk.nodeTool "<command>"` or `dk.uvTool "<command>"` when another hook needs project dependencies. For example, set `hooks.prettier.package = dk.nodeTool "prettier";` for Prettier plugins, or use `dk.nodeTool "cspell"` for npm dictionaries.

Add `dk.nodeToolchain` and `dk.uvToolchain` to the dev shell to match the Node.js and pnpm used by `nodeTool` and the uv version that [`mkLib` selects](flake.md) for `uvTool`.

```nix
packages = builtins.attrValues dk.nodeToolchain ++ builtins.attrValues dk.uvToolchain;
```

### Declare pnpm

Declare pnpm in `package.json` with a `devEngines` range that matches the toolchain's major version.

```json
{
  "devEngines": {
    "packageManager": {
      "name": "pnpm",
      "version": "^12.0.0",
      "onFail": "error"
    }
  }
}
```

Omit the top-level `packageManager` field because it makes pnpm download and run that exact version. When `devEngines` names pnpm, npm refuses to run inside the project. Use `pnpm publish` for OIDC trusted publishing and run npm-only commands from outside the checkout.

### Declare uv

Set uv's version floor and interpreter in `pyproject.toml` so they apply to each `uv` invocation, both inside and outside the dev shell.

```toml
[tool.uv]
required-version = ">=0.13"
python-downloads = "never"
python-preference = "only-system"
```

Use `required-version` to stop older versions of uv before they rewrite `uv.lock` to an older revision. The `system` preference allows a `.venv` built with a uv-managed Python to stay in place. Set `only-system` to replace that environment with the dev shell's Python, and include the `pkgs.python3xx` that satisfies `requires-python` in the shell.

## Exclude files

The baseline excludes paths containing a `fixtures/` component to preserve fixture inputs byte for byte. Use `excludes` to extend that list.
