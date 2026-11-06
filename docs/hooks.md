# Hooks

The baseline enables these hooks:

| Hook                                                                         | Checks                                             | Config                     |
| ---------------------------------------------------------------------------- | -------------------------------------------------- | -------------------------- |
| `actionlint`                                                                 | Workflows                                          | `.github/actionlint.yaml`  |
| `check-added-large-files`                                                    | Every file                                         |                            |
| `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` | Every text file                                    |                            |
| `check-yaml`                                                                 | YAML syntax                                        |                            |
| `cspell`                                                                     | Spelling in every file                             | `cspell.json`              |
| `deadnix`, `nixfmt`, and `statix`                                            | Nix                                                |                            |
| `editorconfig-checker`                                                       | The properties `.editorconfig` sets, in every file | `.editorconfig`            |
| `markdownlint-cli2`                                                          | Markdown                                           | `.markdownlint-cli2.jsonc` |
| `prettier`                                                                   | JavaScript, JSON, and YAML                         | `.prettierrc.json`         |
| `shellcheck`                                                                 | Every shell file except zsh                        |                            |
| `shfmt`                                                                      | Every shell file, zsh included                     | `.editorconfig`            |
| `sort-file-contents`                                                         | The order of `.cspell/words.txt`                   |                            |
| `taplo`                                                                      | TOML                                               |                            |

git-hooks.nix's [`modules/hooks.nix`](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) defines each hook's settings, and devkit's own config files are working examples.

The baseline excludes any path with a `fixtures/` component, since fixtures are byte-for-byte inputs that no hook may rewrite. `excludes` adds to that list.

## Set up the dev shell and the check

`preCommit` returns `check` and `shell`. `hooks` applies to both runs, and `devHooks` only to the shell. A hook named in `devHooks` is disabled in `check`, even when `hooks` enables its nixpkgs counterpart, so a lockfile-pinned tool never runs at its older sandboxed version, and CI runs no `devHooks` entry.

List `preCommit.shell` in the `inputsFrom` of the repository's `pkgs.mkShell`, which puts the hook packages and `prek` after the shell's own `packages` and `nativeBuildInputs`, so a consumer toolchain wins on `PATH`. Its `shellHook` starts with `unset PYTHONPATH`, since `nix develop` inherits an outer value that would shadow a uv venv.

`src` must be the flake's root, with that flake at the checkout root. The shell installs the hooks on entry only when `src/flake.nix` matches the checkout's `flake.nix`, so a shell borrowed from a sibling repository leaves that checkout alone. The installer clears a local `core.hooksPath`, so a repository that needs one sets it in its own `shellHook`, which runs after the installer.

## Override a hook

`hooks` merges recursively with the baseline, whose leaves are `lib.mkOverride 900`, so a consumer definition wins:

```nix
preCommit = dk.preCommit {
  src = ./.;
  hooks = {
    prettier.files = "\\.(js|mjs|json|jsonc|ya?ml)$";
    trim-trailing-whitespace.excludes = [ "\\.patch$" ];
  };
};
```

## Run a lockfile-pinned tool

`dk.nodeTool "<command>"` returns a package that runs `pnpm exec <command>`, and `dk.uvTool "<command>"` one that runs `uv run --locked <command>`. Set either as a builtin hook's `package` under `devHooks`, since the check's sandbox has neither `node_modules` nor a venv. The hook builds its entry from that package, so it keeps the flags its settings produce. A builtin the baseline leaves off, such as mypy, also needs `enable = true`:

```nix
devHooks = {
  mypy = {
    enable = true;
    package = dk.uvTool "mypy";
  };
  prettier.package = dk.nodeTool "prettier";
};
```

Set `verifyDepsBeforeRun: install` in `pnpm-workspace.yaml`, so a run installs a missing or stale `node_modules` first.
