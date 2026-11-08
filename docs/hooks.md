# Hooks

Only `check-added-large-files`, `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` are enabled by default. Enable other hooks with `hooks.<name>.enable = true;`.

The shared hook configurations cover:

| Hook                                                                     | Checks                             | Config                    |
| ------------------------------------------------------------------------ | ---------------------------------- | ------------------------- |
| `actionlint`                                                             | Workflows                          | `.github/actionlint.yaml` |
| `check-added-large-files`                                                | Every file                         |                           |
| `check-merge-conflicts`, `end-of-file-fixer`, `trim-trailing-whitespace` | Every text file                    |                           |
| `check-yaml`                                                             | YAML syntax                        |                           |
| `cspell`                                                                 | Spelling in every file             | `cspell.json`             |
| `deadnix`, `nixfmt`, `statix`                                            | Nix                                |                           |
| `doctoc`                                                                 | Markdown tables of contents        |                           |
| `dprint`                                                                 | Markdown formatting                |                           |
| `editorconfig-checker`                                                   | EditorConfig properties            | `.editorconfig`           |
| `markdownlint-cli2`                                                      | Markdown                           | Shared defaults           |
| `prettier`                                                               | JavaScript, TypeScript, JSON, YAML | Shared defaults           |
| `shellcheck`                                                             | Every shell file except zsh        |                           |
| `shfmt`                                                                  | Every shell file, zsh included     |                           |
| `sort-file-contents`                                                     | The order of `.cspell/words.txt`   |                           |
| `taplo`                                                                  | TOML                               | `.taplo.toml`             |

git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines each hook's settings.

## Configure the baseline

- **cspell:** Add a `cspell.json` that names a project dictionary, such as `.cspell/words.txt`.
- **doctoc:** Fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.
- **dprint and markdownlint-cli2:** dprint formats Markdown, and markdownlint-cli2 checks it with devkit's rules, including `<!-- dprint-ignore -->` blocks. Project `.markdownlint-cli2.jsonc` rules override the defaults. Core `.markdownlint.jsonc` files replace the shared rules. Configured `globs` are ignored, since the hook supplies the file list.
- **Prettier:** Uses devkit's shared configuration unless the source root contains `.prettierrc.json`. Set `hooks.prettier.settings.configPath` for another configuration file.
- **shellcheck:** Start the repository's `.envrc` with `# shellcheck shell=bash`, since prek tags `.envrc` as a bash file and shellcheck rejects one without a shebang or shell directive.
- **Taplo:** Uses the source root's `.taplo.toml` when present and otherwise runs with its defaults.

### Exclude fixtures

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.

## Check Nushell files

Set `hooks.nu-check.enable = true;` to check Nushell files with `dk.nu-check`. When enabled, `editorconfig-checker` checks indentation against a `[*.nu]` section in `.editorconfig`. No hook runs `nufmt`.

## Set up the dev shell and the check

`preCommit` returns `check` and `shell`:

- `hooks` applies to both outputs.
- `devHooks` applies only to the shell, and any hook listed here is disabled in `check` even if `hooks` enables it.

Add `preCommit.shell` to the `inputsFrom` of the repository's `pkgs.mkShell`. The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Entering the dev shell from a Git checkout installs the hooks. The configuration path must be absent or a symlink into the Nix store.

## Override a hook

Definitions under `hooks` merge recursively with the baseline and override its defaults:

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

## Run a lockfile-pinned tool

- `dk.nodeTool "<command>"` returns a package that runs `pnpm exec <command>`.
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
