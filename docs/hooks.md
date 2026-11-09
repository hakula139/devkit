# Hooks

Only `check-added-large-files`, `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` are enabled by default. Enable other hooks with `hooks.<name>.enable = true;`.

The shared hook configurations cover:

| Hook                                                                     | Checks                             | Config                                      |
| ------------------------------------------------------------------------ | ---------------------------------- | ------------------------------------------- |
| `actionlint`                                                             | Workflows                          | `.github/actionlint.yaml`                   |
| `check-added-large-files`                                                | Every file                         |                                             |
| `check-merge-conflicts`, `end-of-file-fixer`, `trim-trailing-whitespace` | Every text file                    |                                             |
| `check-yaml`                                                             | YAML syntax                        |                                             |
| `cspell`                                                                 | Spelling in every file             | `cspell.json`                               |
| `deadnix`, `nixfmt`, `statix`                                            | Nix                                |                                             |
| `doctoc`                                                                 | Markdown tables of contents        |                                             |
| `dprint`                                                                 | Markdown formatting                |                                             |
| `editorconfig-checker`                                                   | EditorConfig properties            | `.editorconfig`                             |
| `markdownlint-cli2`                                                      | Markdown                           | Shared defaults, `.markdownlint-cli2.jsonc` |
| `prettier`                                                               | JavaScript, TypeScript, JSON, YAML | Shared defaults, `.prettierrc.json`         |
| `ruff`, `ruff-format`                                                    | Python, type stubs, notebooks      | `ruff.toml`                                 |
| `shellcheck`                                                             | Every shell file except zsh        |                                             |
| `shfmt`                                                                  | Every shell file, zsh included     |                                             |
| `sort-file-contents`                                                     | The order of `.cspell/words.txt`   |                                             |
| `taplo`                                                                  | TOML                               | Shared defaults, `.taplo.toml`              |

git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines each hook's settings.

## Configure the baseline

- **cspell:** Add a `cspell.json` that names a project dictionary, such as `.cspell/words.txt`. A dictionary at another path needs `hooks.sort-file-contents.files` to stay sorted.
- **doctoc:** Fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.
- **dprint and markdownlint-cli2:** dprint formats Markdown, and markdownlint-cli2 checks it with devkit's [shared rules](../.markdownlint-cli2.jsonc), including `<!-- dprint-ignore -->` blocks. Project `.markdownlint-cli2.jsonc` rules override them, core `.markdownlint.jsonc` files replace them, and configured `globs` are ignored.
- **Prettier:** Uses devkit's [shared style](../.prettierrc.json) unless the source root contains `.prettierrc.json`.
- **shellcheck:** Start the repository's `.envrc` with `# shellcheck shell=bash`, since prek tags `.envrc` as a bash file and shellcheck rejects one without a shebang or shell directive.
- **Taplo:** Uses devkit's [shared formatting](../.taplo.toml) unless the source root contains `.taplo.toml`.

The shared defaults apply only to the hook, so editors and scripts that run Prettier, markdownlint-cli2, or Taplo directly still need a project configuration file.

Set `hooks.<name>.settings.configPath` to pass markdownlint-cli2, Prettier, Ruff, or Taplo another `--config` file, relative to the checkout or absolute, or `""` to let the tool find its own. markdownlint-cli2 accepts only names ending in a supported name, such as `.markdownlint-cli2.jsonc`. A markdownlint-cli2 configuration with relative `customRules` or `markdownItPlugins` needs `configPath = ".markdownlint-cli2.jsonc"`, which replaces the shared rules. Re-enter the dev shell after adding or removing a project configuration file.

### Exclude fixtures

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.

## Check Nushell files

Set `hooks.nu-check.enable = true;` to check Nushell files with `dk.nu-check`. When enabled, `editorconfig-checker` checks indentation against a `[*.nu]` section in `.editorconfig`. No hook runs `nufmt`, and `hooks.nu-check.settings.asModule` has no effect.

## Set up the dev shell and the check

`preCommit` returns `check` and `shell`:

- `hooks` applies to both outputs.
- `devHooks` applies only to the shell, and any hook listed here is disabled in `check` even if `hooks` enables it.

Add `preCommit.shell` to the `inputsFrom` of the repository's `pkgs.mkShell`. The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Entering the dev shell from a Git checkout installs the hooks. The configuration path must be absent or a symlink into the Nix store.

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

- `dk.nodeTool "<command>"` returns a package that runs `pnpm exec <command>`.
- `dk.nodeToolchain` contains `nodejs` and `pnpm`. Add `builtins.attrValues dk.nodeToolchain` to the dev shell's `packages` to use the same versions as `nodeTool`.
- `dk.uvTool "<command>"` returns a package that runs `uv run --locked <command>`.

Enable the builtin hook and set its `package` under `devHooks`:

```nix
devHooks = {
  mypy = {
    enable = true;
    package = dk.uvTool "mypy";
  };
  prettier = {
    enable = true;
    package = dk.nodeTool "prettier";
  };
};
```

Set `verifyDepsBeforeRun: install` in `pnpm-workspace.yaml` so each run installs a missing or stale `node_modules` first.
