# Hooks

The baseline enables these hooks:

| Hook                                                                         | Checks                                             | Config                      |
| ---------------------------------------------------------------------------- | -------------------------------------------------- | --------------------------- |
| `actionlint`                                                                 | Workflows                                          | `.github/actionlint.yaml`   |
| `check-added-large-files`                                                    | Every file                                         |                             |
| `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` | Every text file                                    |                             |
| `check-yaml`                                                                 | YAML syntax                                        |                             |
| `cspell`                                                                     | Spelling in every file                             | `cspell.json`               |
| `deadnix`, `nixfmt`, and `statix`                                            | Nix                                                |                             |
| `doctoc`                                                                     | Markdown tables of contents                        |                             |
| `dprint`                                                                     | Markdown formatting                                |                             |
| `editorconfig-checker`                                                       | The properties `.editorconfig` sets, in every file | `.editorconfig`             |
| `markdownlint-cli2`                                                          | Markdown                                           | `.markdownlint-cli2.jsonc`  |
| `prettier`                                                                   | JavaScript, TypeScript, JSON, and YAML             | `.prettierrc.json`          |
| `shellcheck`                                                                 | Every shell file except zsh                        |                             |
| `shfmt`                                                                      | Every shell file, zsh included                     | `.editorconfig`             |
| `sort-file-contents`                                                         | The order of `.cspell/words.txt`                   |                             |
| `taplo`                                                                      | TOML                                               | `.taplo.toml`, `taplo.toml` |

git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines each hook's settings. devkit's own config files are working examples, and the workflow snippets in these docs follow its `.prettierrc.json`.

`doctoc` fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, and leaves a file without them untouched. Keep reference-style links out of headings, since doctoc builds their anchors from the raw source and `markdownlint-cli2` passes the broken entry.

`dprint` formats Markdown before `markdownlint-cli2` lints it. The style rules in `.markdownlint-cli2.jsonc` match dprint's output, so the same style applies where dprint doesn't format, such as in a `<!-- dprint-ignore -->` block.

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.

Prettier uses the source root's `.prettierrc.json` or `.prettierrc`, falling back to its defaults, with EditorConfig disabled. This keeps personal configuration out of repository checks. Set `hooks.prettier.settings.configPath` explicitly for another configuration file.

## Check Nushell files

The baseline's `nu-check` hook runs `dk.nu-check`, the `--ide-check` wrapper, on Nushell files, and stays off until `hooks.nu-check.enable = true;`. Because `nufmt` reindents to four spaces, no hook runs it, and only `editorconfig-checker` checks Nushell indentation against a `[*.nu]` section in `.editorconfig` such as devkit's.

## Set up the dev shell and the check

`preCommit` returns `check` and `shell`. `hooks` applies to both, while `devHooks` applies only to the shell. Naming a hook in `devHooks` disables it in `check`, even when `hooks` enables its nixpkgs counterpart, so a lockfile-pinned tool never runs at its older sandboxed version and CI never runs a `devHooks` entry.

List `preCommit.shell` in the `inputsFrom` of the repository's `pkgs.mkShell`. This places the hook packages and `prek` after the shell's own `packages` and `nativeBuildInputs`, so a consumer toolchain wins on `PATH`. Its `shellHook` starts with `unset PYTHONPATH`, since the hook packages' Python setup hook sets that variable and `nix develop` inherits any outer value, either of which would shadow a uv venv.

The shell installs the hooks when entered from a Git checkout. The generated configuration is registered as an indirect Nix GC root before installing prek's configured stages. The configuration path must be absent or a symlink into the Nix store. Installation is serialized across linked worktrees.

## Override a hook

`hooks` merges recursively with the baseline, whose leaves use `lib.mkOverride 900`, so a consumer definition wins:

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

`dk.nodeTool "<command>"` returns a package that runs `pnpm exec <command>`, and `dk.uvTool "<command>"` returns one that runs `uv run --locked <command>`. Set either as a builtin hook's `package` under `devHooks`, since the check's sandbox has neither `node_modules` nor a venv. The hook builds its entry from that package, so it keeps the flags its settings produce. A builtin that the baseline leaves off, such as mypy, also needs `enable = true`:

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
