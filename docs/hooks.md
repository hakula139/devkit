# Hooks

`lib.preCommit` runs `nix/hooks.nix`'s baseline in every adopting repository, so a change that passes in one repository cannot fail in a sibling only because a hook is missing. The baseline's hooks and their files live in that file.

Two settings differ from the hook defaults: shellcheck reads only `sh`, `bash`, `dash`, and `ksh`, since it cannot parse zsh, and `shfmt` passes no formatting flag, so it reads `.editorconfig` and keeps `binary_next_line` and `switch_case_indent`. A shell file that no `.editorconfig` section covers falls back to tabs. `excludes` defaults to `[ "(^|/)fixtures/" ]`, since fixtures are byte-for-byte inputs.

## Override a hook

`hooks` merges recursively with the baseline:

```nix
preCommit = devkit.lib.preCommit {
  inherit pkgs;
  src = ./.;
  hooks = {
    prettier.files = "\\.(js|json|jsonc|ya?ml)$";
    trim-trailing-whitespace.excludes = [ "\\.patch$" ];
  };
};
```

Other language hooks stay opt-in through git-hooks.nix's own entries.

## Run a lockfile-pinned Node tool

`lib.nodeHook` returns a hook entry that runs `node_modules/.bin/<command>` from the repository root with `nodejs` on `PATH`:

```nix
devHooks.prettier = {
  enable = true;
  entry = devkit.lib.nodeHook {
    inherit pkgs;
    command = "prettier";
  };
};
```

It exits 1 when `node_modules` is missing, since a check that skips itself there reports success without reading a file.

## Dev shell and the check

`lib.preCommit` returns `dev` and `check`. `hooks` applies to both, `devHooks` only to `dev`, and `checkHooks` only to `check`, for a package the sandbox needs. A hook named in `devHooks` is disabled in `check`, even when `hooks` enables its nixpkgs counterpart, so a lockfile-pinned tool never runs at its older sandboxed version.

```nix
checks.pre-commit = preCommit.check;

devShells.default = devkit.lib.mkDevShell {
  inherit pkgs preCommit;
  marker = "src/my-tool.nu";
  packages = [ pkgs.nu ];
};
```

`lib.mkDevShell` puts the consumer's `packages` first, then the hook packages and `prek`, so a consumer toolchain wins on `PATH`. It sets `dontAddPythonPath = true`, since a hook's Python package would otherwise shadow a uv venv. It installs the hooks on entry only when `marker` exists, so `nix develop` borrowed from a sibling repository leaves the checkout alone, and it clears `core.hooksPath` for linked worktrees (cachix/git-hooks.nix#688). The caller's `shellHook` runs after the installer, and other arguments pass to `pkgs.mkShell`.

`lib.preCommit` needs a system git-hooks.nix supports: `aarch64-darwin`, `aarch64-linux`, or `x86_64-linux`. Those are `lib.systems`, and `lib.eachSystem` builds a flake's per-system outputs.
