# Hooks

## Set up the dev shell

`preCommit` returns a dev shell. Add it to the `inputsFrom` of the repository's `pkgs.mkShell`. The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Entering the dev shell from a Git checkout installs the hooks. The configuration path must be absent or a symlink into the Nix store.

`run-hooks` runs every enabled hook outside the `manual` stage on every tracked file, one stage at a time, or only the hooks whose IDs it receives as arguments. It first installs the lockfile of each enabled hook whose package comes from `dk.nodeTool` or `dk.uvTool`. `nix flake check` runs no hooks, so verify a change with `nix develop -c run-hooks` as well, as [`nix.yml`](ci.md) does in CI.

## Enable hooks

Only `check-added-large-files`, `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` are enabled by default. Enable other hooks with `hooks.<name>.enable = true;`.

The shared hook configurations cover:

| Group                   | Hook                       | Checks                                                      | Config                                      |
| ----------------------- | -------------------------- | ----------------------------------------------------------- | ------------------------------------------- |
| General                 | `check-added-large-files`  | File sizes                                                  |                                             |
|                         | `check-merge-conflicts`    | Conflict markers in every text file                         |                                             |
|                         | `cspell`                   | Spelling in every file                                      | `cspell.json`                               |
|                         | `editorconfig-checker`     | EditorConfig properties                                     | `.editorconfig`                             |
|                         | `end-of-file-fixer`        | Final newlines in every text file                           |                                             |
|                         | `lychee`                   | Links                                                       | `lychee.toml`                               |
|                         | `sort-file-contents`       | The order of `.cspell/words.txt`                            |                                             |
|                         | `trim-trailing-whitespace` | Trailing whitespace in every text file                      |                                             |
| GitHub Actions          | `actionlint`               | Workflows                                                   | `.github/actionlint.yaml`                   |
| JavaScript / TypeScript | `eslint`                   | Lint                                                        | `eslint.config.js`                          |
|                         | `tsc`                      | Types                                                       | `tsconfig.json`                             |
| Markdown                | `doctoc`                   | Tables of contents                                          |                                             |
|                         | `dprint`                   | Formatting                                                  |                                             |
|                         | `markdownlint-cli2`        | Lint                                                        | Shared defaults, `.markdownlint-cli2.jsonc` |
| Nix                     | `deadnix`                  | Unused code                                                 |                                             |
|                         | `nixfmt`                   | Formatting                                                  |                                             |
|                         | `statix`                   | Lint                                                        |                                             |
| Nushell                 | `nu-check`                 | Syntax                                                      |                                             |
| Python                  | `mypy`                     | Types                                                       | `[tool.mypy]` in `pyproject.toml`           |
|                         | `ruff`                     | Lint, type stubs and notebooks included                     | Ruff configuration                          |
|                         | `ruff-format`              | Formatting, type stubs and notebooks included               | Ruff configuration                          |
| Rust                    | `clippy`                   | Lint                                                        | `Cargo.toml` `[lints]`, `clippy.toml`       |
|                         | `rustfmt`                  | Formatting                                                  | `rustfmt.toml`                              |
| Shell                   | `shellcheck`               | Lint, every shell file except zsh                           |                                             |
|                         | `shfmt`                    | Formatting, every shell file, zsh included                  |                                             |
| TOML                    | `taplo`                    | Formatting                                                  | Shared defaults, `.taplo.toml`              |
| Web formats             | `prettier`                 | JavaScript, TypeScript, JSON, YAML, except `pnpm-lock.yaml` | Shared defaults, `.prettierrc.json`         |
| YAML                    | `check-yaml`               | Syntax                                                      |                                             |

git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines each hook's settings.

## Configure a hook

### Override the baseline

A definition under `hooks` replaces the baseline's value of that attribute, except that `args` and `excludes` concatenate with the baseline's lists. Place a list's items with `lib.mkBefore` or `lib.mkAfter`, or replace the baseline's list with `lib.mkForce`:

```nix
preCommit = dk.preCommit {
  src = ./.;
  hooks = {
    prettier = {
      enable = true;
      files = "\\.(js|mjs|json|jsonc|ya?ml)$";
    };
    trim-trailing-whitespace.excludes = [
      "\\.patch$"
    ];
  };
};
```

ESLint and clippy fail on warnings, since prek hides the output of a passing hook.

### Use a project configuration file

- **Prettier and Taplo:** Use devkit's [shared style](../.prettierrc.json) and [shared formatting](../.taplo.toml) unless the source root contains `.prettierrc.json` or `.taplo.toml`, which replaces the shared file entirely and so restates the shared options it keeps.
- **markdownlint-cli2:** Checks Markdown with devkit's [shared rules](../.markdownlint-cli2.jsonc), including `<!-- dprint-ignore -->` blocks that dprint leaves unformatted. Project `.markdownlint-cli2.jsonc` rules override them, core `.markdownlint.jsonc` files replace them, and configured `globs` are ignored.

Set `hooks.<name>.settings.configPath` to pass markdownlint-cli2, Prettier, Ruff, or Taplo another `--config` file, relative to the checkout or absolute, or `""` to let the tool find its own. markdownlint-cli2 accepts only names ending in a supported name, such as `.markdownlint-cli2.jsonc`. A markdownlint-cli2 configuration with relative `customRules` or `markdownItPlugins` needs `configPath = ".markdownlint-cli2.jsonc"`, which replaces the shared rules.

Re-enter the dev shell after adding or removing a project configuration file.

### Add a spelling dictionary

Add a `cspell.json` that names a project dictionary, such as `.cspell/words.txt`. A dictionary at another path needs `hooks.sort-file-contents.files` to stay sorted.

### Generate Markdown tables of contents

doctoc fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.

### Check Nushell files

`nu-check` checks Nushell files with `dk.nu-check`. When it is enabled, `editorconfig-checker` checks indentation against a `[*.nu]` section in `.editorconfig`. No hook runs `nufmt`, and `hooks.nu-check.settings.asModule` has no effect.

### Type-check Python

mypy checks the `files` that `[tool.mypy]` names, ignoring which files changed.

### Lint and format Rust

Set `packageOverrides` to the repository's toolchain, as `{ cargo = rustToolchain; clippy = rustToolchain; }` for clippy and `{ cargo = rustToolchain; rustfmt = rustToolchain; }` for rustfmt.

clippy runs `cargo clippy --locked --all-targets` with default features. Cargo flags go in `hooks.clippy.settings`, such as `allFeatures = true`, and an `extraArgs` replaces the baseline's `--locked --all-targets`. `args` reach clippy after `--`, and lint levels belong in `Cargo.toml` `[lints]`.

### Check shell files

Start the repository's `.envrc` with `# shellcheck shell=bash`, since prek tags `.envrc` as a bash file and shellcheck rejects one without a shebang or shell directive.

## Run a lockfile-pinned tool

- `dk.nodeTool "<command>"` returns a package that runs `pnpm exec <command>`, whose lockfile `run-hooks` installs with `pnpm install --frozen-lockfile`.
- `dk.nodeToolchain` contains `nodejs` and `pnpm`. Add `builtins.attrValues dk.nodeToolchain` to the dev shell's `packages` to use the same versions as `nodeTool`.
- `dk.uvTool "<command>"` returns a package that runs `uv run --locked <command>`, whose lockfile `run-hooks` installs with `uv sync --locked`.

`eslint` and `tsc` use `dk.nodeTool` and `mypy` uses `dk.uvTool` by default. Set `package` to `dk.nodeTool "prettier"` for Prettier with plugins, or to `dk.nodeTool "cspell"` for cspell with npm dictionaries.

### Declare pnpm

Declare pnpm in `package.json` as `"devEngines": { "packageManager": { "name": "pnpm", "version": "^12.0.0", "onFail": "error" } }`, matching the toolchain's major, without a `packageManager` field, which would make pnpm download and run that exact version instead. npm refuses to run in a project whose `devEngines` names pnpm, so publish with `pnpm publish`, which runs npm's OIDC trusted publishing, and run npm-only commands from outside the checkout.

## Exclude files

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.
