# Hooks

The baseline enables these hooks:

| Hook                                                                         | Checks                                 | Config                     |
| ---------------------------------------------------------------------------- | -------------------------------------- | -------------------------- |
| `actionlint`                                                                 | Workflows                              | `.github/actionlint.yaml`  |
| `check-added-large-files`                                                    | Every file                             |                            |
| `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` | Every text file                        |                            |
| `check-yaml`                                                                 | YAML syntax                            |                            |
| `cspell`                                                                     | Spelling in every file                 | `cspell.json`              |
| `deadnix`, `nixfmt`, and `statix`                                            | Nix                                    |                            |
| `doctoc`                                                                     | Markdown tables of contents            |                            |
| `dprint`                                                                     | Markdown formatting                    |                            |
| `editorconfig-checker`                                                       | EditorConfig properties                | `.editorconfig`            |
| `markdownlint-cli2`                                                          | Markdown                               | `.markdownlint-cli2.jsonc` |
| `prettier`                                                                   | JavaScript, TypeScript, JSON, and YAML | `.prettierrc.json`         |
| `shellcheck`                                                                 | Every shell file except zsh            |                            |
| `shfmt`                                                                      | Every shell file, zsh included         | `.editorconfig`            |
| `sort-file-contents`                                                         | The order of `.cspell/words.txt`       |                            |
| `taplo`                                                                      | TOML                                   | `.taplo.toml`              |

git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines each hook's settings, and devkit's own config files are working examples.

## Configure the baseline

- **doctoc:** Fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. Keep reference-style links out of headings, since doctoc builds their anchors from the raw source and `markdownlint-cli2` passes the broken entry.
- **dprint and markdownlint-cli2:** dprint formats Markdown before markdownlint-cli2 runs, and markdownlint-cli2 then checks the rules in `.markdownlint-cli2.jsonc`, including inside `<!-- dprint-ignore -->` blocks.
- **Prettier:** Uses the source root's `.prettierrc.json` when present and otherwise runs with its defaults. EditorConfig and configuration lookup are disabled to keep personal configuration out of repository checks. Set `hooks.prettier.settings.configPath` explicitly for another configuration file.
- **Taplo:** Uses the source root's `.taplo.toml` when present and otherwise runs with its defaults. Automatic configuration lookup is disabled to keep personal configuration out of repository checks.

### Exclude fixtures

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.

## Check Nushell files

Set `hooks.nu-check.enable = true;` to check Nushell files with `dk.nu-check`. `editorconfig-checker` checks indentation against a `[*.nu]` section in `.editorconfig`, and no hook runs `nufmt`.

## Set up the dev shell and the check

`preCommit` returns `check` and `shell`:

- `hooks` applies to both outputs.
- `devHooks` applies only to the shell, and any hook listed here is disabled in `check` even if `hooks` enables it.

Add `preCommit.shell` to the `inputsFrom` of the repository's `pkgs.mkShell`. The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Entering the dev shell from a Git checkout installs the hooks, provided the configuration path is absent or a symlink into the Nix store.

## Override a hook

Definitions under `hooks` merge recursively with the baseline and override its defaults:

```nix
preCommit = dk.preCommit {
  src = ./.;
  hooks = {
    prettier.files = "\\.(js|mjs|json|jsonc|ya?ml)$";
    trim-trailing-whitespace.excludes = [
      "\\.patch$"
    ];
  };
};
```

## Run a lockfile-pinned tool

`dk.nodeTool "<command>"` returns a package that runs `pnpm exec <command>`, and `dk.uvTool "<command>"` returns one that runs `uv run --locked <command>`. Set either as a builtin hook's `package` under `devHooks`. A builtin that the baseline leaves off, such as mypy, also needs `enable = true`:

```nix
devHooks = {
  mypy = {
    enable = true;
    package = dk.uvTool "mypy";
  };
  prettier.package = dk.nodeTool "prettier";
};
```

Set `verifyDepsBeforeRun: install` in `pnpm-workspace.yaml` so each run installs a missing or stale `node_modules` first.
