# Hooks

Only `check-added-large-files`, `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` are enabled by default. Enable other hooks with `hooks.<name>.enable = true;`.

The shared hook configurations cover:

| Hook                                                                     | Checks                             | Config                                                |
| ------------------------------------------------------------------------ | ---------------------------------- | ----------------------------------------------------- |
| `actionlint`                                                             | Workflows                          | `.github/actionlint.yaml`                             |
| `check-added-large-files`                                                | Every file                         |                                                       |
| `check-merge-conflicts`, `end-of-file-fixer`, `trim-trailing-whitespace` | Every text file                    |                                                       |
| `check-yaml`                                                             | YAML syntax                        |                                                       |
| `clippy`, `rustfmt`                                                      | Rust                               | `Cargo.toml` `[lints]`, `clippy.toml`, `rustfmt.toml` |
| `cspell`                                                                 | Spelling in every file             | `cspell.json`                                         |
| `deadnix`, `nixfmt`, `statix`                                            | Nix                                |                                                       |
| `doctoc`                                                                 | Markdown tables of contents        |                                                       |
| `dprint`                                                                 | Markdown formatting                |                                                       |
| `editorconfig-checker`                                                   | EditorConfig properties            | `.editorconfig`                                       |
| `eslint`                                                                 | JavaScript and TypeScript          | `eslint.config.js`                                    |
| `markdownlint-cli2`                                                      | Markdown                           | Shared defaults, `.markdownlint-cli2.jsonc`           |
| `mypy`                                                                   | Python types                       | `[tool.mypy]` in `pyproject.toml`                     |
| `prettier`                                                               | JavaScript, TypeScript, JSON, YAML | Shared defaults, `.prettierrc.json`                   |
| `ruff`, `ruff-format`                                                    | Python, type stubs, notebooks      | Ruff configuration                                    |
| `shellcheck`                                                             | Every shell file except zsh        |                                                       |
| `shfmt`                                                                  | Every shell file, zsh included     |                                                       |
| `sort-file-contents`                                                     | The order of `.cspell/words.txt`   |                                                       |
| `taplo`                                                                  | TOML                               | Shared defaults, `.taplo.toml`                        |
| `tsc`                                                                    | TypeScript types                   | `tsconfig.json`                                       |

git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines each hook's settings.

## Configure the baseline

- **clippy and rustfmt:** Set `packageOverrides` to the repository's toolchain, as `{ cargo = rustToolchain; clippy = rustToolchain; }` for clippy and `{ cargo = rustToolchain; rustfmt = rustToolchain; }` for rustfmt. clippy runs `cargo clippy --locked --all-targets` with default features, takes Cargo flags such as `--all-features` or `--manifest-path` in `args`, and ignores `hooks.clippy.settings`. Failing on warnings needs Cargo 1.97 or later.
- **cspell:** Add a `cspell.json` that names a project dictionary, such as `.cspell/words.txt`. A dictionary at another path needs `hooks.sort-file-contents.files` to stay sorted.
- **doctoc:** Fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.
- **dprint and markdownlint-cli2:** dprint formats Markdown, and markdownlint-cli2 checks it with devkit's [shared rules](../.markdownlint-cli2.jsonc), including `<!-- dprint-ignore -->` blocks. Project `.markdownlint-cli2.jsonc` rules override them, core `.markdownlint.jsonc` files replace them, and configured `globs` are ignored.
- **mypy:** Checks the `files` that `[tool.mypy]` names, ignoring which files changed.
- **Prettier:** Uses devkit's [shared style](../.prettierrc.json) unless the source root contains `.prettierrc.json`, which replaces it entirely and so restates the shared options it keeps.
- **shellcheck:** Start the repository's `.envrc` with `# shellcheck shell=bash`, since prek tags `.envrc` as a bash file and shellcheck rejects one without a shebang or shell directive.
- **Taplo:** Uses devkit's [shared formatting](../.taplo.toml) unless the source root contains `.taplo.toml`, which replaces it entirely and so restates the shared options it keeps.

ESLint and clippy fail on warnings, since prek hides the output of a passing hook.

Set `hooks.<name>.settings.configPath` to pass markdownlint-cli2, Prettier, Ruff, or Taplo another `--config` file, relative to the checkout or absolute, or `""` to let the tool find its own. markdownlint-cli2 accepts only names ending in a supported name, such as `.markdownlint-cli2.jsonc`. A markdownlint-cli2 configuration with relative `customRules` or `markdownItPlugins` needs `configPath = ".markdownlint-cli2.jsonc"`, which replaces the shared rules. Re-enter the dev shell after adding or removing a project configuration file.

### Exclude fixtures

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.

## Check Nushell files

Set `hooks.nu-check.enable = true;` to check Nushell files with `dk.nu-check`. When enabled, `editorconfig-checker` checks indentation against a `[*.nu]` section in `.editorconfig`. No hook runs `nufmt`, and `hooks.nu-check.settings.asModule` has no effect.

## Set up the dev shell

`preCommit` returns a dev shell. Add it to the `inputsFrom` of the repository's `pkgs.mkShell`. The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Entering the dev shell from a Git checkout installs the hooks. The configuration path must be absent or a symlink into the Nix store.

`run-hooks` runs every enabled hook outside the `manual` stage on every tracked file, one stage at a time, or only the hooks whose IDs it receives as arguments. It first installs the lockfile of each enabled hook whose package comes from `dk.nodeTool` or `dk.uvTool`. `nix flake check` runs no hooks, so verify a change with `nix develop -c run-hooks` as well.

## Override a hook

Definitions under `hooks` replace the baseline's values attribute by attribute:

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

The baseline passes its own flags in `entry`, so `args` holds only the repository's flags.

## Run a lockfile-pinned tool

- `dk.nodeTool "<command>"` returns a package that runs `pnpm exec <command>`, whose lockfile `run-hooks` installs with `pnpm install --frozen-lockfile`.
- `dk.nodeToolchain` contains `nodejs` and `pnpm`. Add `builtins.attrValues dk.nodeToolchain` to the dev shell's `packages` to use the same versions as `nodeTool`. Declare pnpm in `package.json` as `"devEngines": { "packageManager": { "name": "pnpm", "version": "^12.0.0", "onFail": "error" } }`, matching the toolchain's major, without a `packageManager` field, which would make pnpm download and run that exact version instead. npm refuses to run in such a project, so publish a package with `npm publish` on a `pnpm pack` tarball outside the checkout.
- `dk.uvTool "<command>"` returns a package that runs `uv run --locked <command>`, whose lockfile `run-hooks` installs with `uv sync --locked`.

`eslint` and `tsc` use `dk.nodeTool` and `mypy` uses `dk.uvTool` by default. Set `package` to `dk.nodeTool "prettier"` for Prettier with plugins, or to `dk.nodeTool "cspell"` for cspell with npm dictionaries.
