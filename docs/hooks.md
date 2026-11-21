# Hooks

## Set up the dev shell

Add `preCommit` to `inputsFrom` as shown in [Nix flake](flake.md). The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Enter the dev shell from the intended checkout. Its configuration path must be absent or a symlink into the Nix store. Installing prek's shims replaces existing hooks and follows hook symlinks, overwriting their targets.

The hook installation reports on stderr, so `nix develop -c <cmd>` writes only the command's output to stdout. A repository's own `shellHook` must keep stdout clean too.

Run `run-hooks` separately from `nix flake check`, as CI does. It prepares dependencies for enabled lockfile-pinned tools and checks tracked files across the pre-commit, pre-merge-commit, and pre-push stages. Pass hook IDs to run a subset, such as `nix develop -c run-hooks cspell`.

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

A definition under `hooks` replaces the baseline's value, while `args` and `excludes` append to the baseline's lists unless wrapped in `lib.mkForce`:

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

Add a `cspell.json` that names a project dictionary. `sort-file-contents` keeps `.cspell/words.txt` sorted, and a dictionary at another path needs `hooks.sort-file-contents.files` set to match it.

### Generate Markdown tables of contents

doctoc fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.

### Format Markdown

Keep Markdown under dprint so fenced examples retain their indentation and blank lines and embedded HTML stays intact. It formats the files selected by prek even when Git ignore rules match a tracked file. Preserve the Markdown override in `.editorconfig` so editors retain two-space hard line breaks.

### Check EditorConfig properties

Keep a copy of the shared `.editorconfig` checked in, then add language-specific sections that match the repository's formatters. EditorConfig has no include mechanism, and editors use this file outside the dev shell. Nushell indentation is checked through this file because no hook formats Nushell.

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

Point clippy and rustfmt at the repository's toolchain:

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

Start the repository's `.envrc` with a shell directive, which shellcheck needs to lint a file without a shebang:

```bash
# shellcheck shell=bash
```

## Run a lockfile-pinned tool

ESLint and TypeScript already run from the project's pnpm lockfile, and mypy runs from its uv lockfile. Use `dk.nodeTool "<command>"` or `dk.uvTool "<command>"` when another hook needs project dependencies. For example, set `hooks.prettier.package = dk.nodeTool "prettier";` for Prettier plugins, or use `dk.nodeTool "cspell"` for npm dictionaries.

Add `dk.nodeToolchain` to the dev shell to use the same Node.js and pnpm as `nodeTool`, and `dk.uvToolchain` to use the same uv as `uvTool`, which is the uv that [`mkLib` selects](flake.md):

```nix
packages = builtins.attrValues dk.nodeToolchain ++ builtins.attrValues dk.uvToolchain;
```

### Declare pnpm

Declare pnpm in `package.json` with `devEngines`, matching the toolchain's major:

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

Leave out a `packageManager` field, which would make pnpm download and run that exact version instead. npm refuses to run in a project whose `devEngines` names pnpm, so publish with `pnpm publish`, which supports OIDC trusted publishing, and run npm-only commands from outside the checkout.

### Declare uv

Set uv's version floor and interpreter in `pyproject.toml`, which every `uv` invocation reads, inside the dev shell or not:

```toml
[tool.uv]
required-version = ">=0.13"
python-downloads = "never"
python-preference = "only-system"
```

`required-version` stops an older uv before it rewrites `uv.lock` to an older revision. `only-system` makes uv use the dev shell's Python, and unlike `system` it also replaces a `.venv` built on a uv-managed Python. Add the `pkgs.python3xx` that satisfies `requires-python` to the dev shell.

## Exclude files

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.
