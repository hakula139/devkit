# Hooks

## Set up the dev shell

`preCommit` returns a dev shell. Add it to the `inputsFrom` of the repository's `pkgs.mkShell`. The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Entering the dev shell from a Git checkout installs the hooks. The configuration path must be absent or a symlink into the Nix store.

`run-hooks` runs the enabled `pre-commit`, `pre-merge-commit`, and `pre-push` hooks on every tracked file, or only the hooks whose IDs it receives, after installing the lockfiles of [lockfile-pinned tools](#run-a-lockfile-pinned-tool). `nix flake check` runs no hooks, so verify a change with `run-hooks` as well, as [`nix.yml`](ci.md) does in CI:

```bash
nix develop -c run-hooks
```

## Enable hooks

The General, GitHub Actions, and Nix hooks are enabled by default, except `cspell` and `lychee`. Disable one with `hooks.<name>.enable = false;`, and enable any other with `hooks.<name>.enable = true;`.

The shared hook configurations cover:

| Group                   | Hook                       | Checks                                           | Config                                      |
| ----------------------- | -------------------------- | ------------------------------------------------ | ------------------------------------------- |
| General                 | `check-added-large-files`  | File sizes                                       |                                             |
|                         | `check-merge-conflicts`    | Conflict markers                                 |                                             |
|                         | `cspell`                   | Spelling                                         | `cspell.json`                               |
|                         | `editorconfig-checker`     | EditorConfig properties                          | `.editorconfig`                             |
|                         | `end-of-file-fixer`        | Final newlines                                   |                                             |
|                         | `lychee`                   | Links                                            | `lychee.toml`                               |
|                         | `sort-file-contents`       | The order of `.cspell/words.txt`                 |                                             |
|                         | `trim-trailing-whitespace` | Trailing whitespace                              |                                             |
| GitHub Actions          | `actionlint`               | Workflows                                        | `.github/actionlint.yaml`                   |
| JavaScript / TypeScript | `eslint`                   | Lint                                             | `eslint.config.js`                          |
|                         | `tsc`                      | Types                                            | `tsconfig.json`                             |
| Markdown                | `doctoc`                   | Tables of contents                               |                                             |
|                         | `dprint`                   | Formatting                                       |                                             |
|                         | `markdownlint-cli2`        | Lint                                             | Shared defaults, `.markdownlint-cli2.jsonc` |
| Nix                     | `deadnix`                  | Unused code                                      |                                             |
|                         | `nixfmt`                   | Formatting                                       |                                             |
|                         | `statix`                   | Lint                                             |                                             |
| Nushell                 | `nu-check`                 | Syntax                                           |                                             |
| Python                  | `mypy`                     | Types                                            | `[tool.mypy]` in `pyproject.toml`           |
|                         | `ruff`                     | Lint                                             | Ruff configuration                          |
|                         | `ruff-format`              | Formatting                                       | Ruff configuration                          |
| Rust                    | `clippy`                   | Lint                                             | `Cargo.toml` `[lints]`, `clippy.toml`       |
|                         | `rustfmt`                  | Formatting                                       | `rustfmt.toml`                              |
| Shell                   | `shellcheck`               | Lint                                             |                                             |
|                         | `shfmt`                    | Formatting                                       |                                             |
| TOML                    | `taplo`                    | Formatting                                       | Shared defaults, `.taplo.toml`              |
| Web formats             | `prettier`                 | Formatting of JavaScript, TypeScript, JSON, YAML | Shared defaults, `.prettierrc.json`         |
| YAML                    | `check-yaml`               | Syntax                                           |                                             |

devkit's [baseline](../nix/hooks/baseline.nix) sets each hook's defaults, and git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines its settings. ESLint and clippy fail on warnings, since prek hides the output of a passing hook.

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

Set `hooks.<name>.settings.configPath` to point markdownlint-cli2, Prettier, Ruff, or Taplo at another file, or to `""` to let the tool find its own. A `.markdownlint-cli2.jsonc` that loads relative `customRules` or `markdownItPlugins` needs `configPath = ".markdownlint-cli2.jsonc"`, which drops the shared rules.

### Add a spelling dictionary

Add a `cspell.json` that names a project dictionary. `sort-file-contents` keeps `.cspell/words.txt` sorted, and a dictionary at another path needs `hooks.sort-file-contents.files` set to match it.

### Generate Markdown tables of contents

doctoc fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.

### Check Nushell files

No hook formats Nushell, so `editorconfig-checker` checks its indentation against a `[*.nu]` section in `.editorconfig`.

### Type-check Python

mypy checks the `files` that `[tool.mypy]` names, whichever files changed.

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

`dk.nodeTool "<command>"` and `dk.uvTool "<command>"` return packages that run the command from the repository's pnpm or uv lockfile, which `run-hooks` installs first. `eslint` and `tsc` use `dk.nodeTool` and `mypy` uses `dk.uvTool` by default. Set `package` to `dk.nodeTool "prettier"` for Prettier with plugins, or to `dk.nodeTool "cspell"` for cspell with npm dictionaries.

Add `dk.nodeToolchain` to the dev shell to use the same Node.js and pnpm as `nodeTool`:

```nix
packages = builtins.attrValues dk.nodeToolchain;
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

Leave out a `packageManager` field, which would make pnpm download and run that exact version instead. npm refuses to run in a project whose `devEngines` names pnpm, so publish with `pnpm publish`, which runs npm's OIDC trusted publishing, and run npm-only commands from outside the checkout.

## Exclude files

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.
