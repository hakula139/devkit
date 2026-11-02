# devkit

[![CI](https://github.com/hakula139/devkit/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/devkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Shared development tooling for Hakula's repositories.

## Contents

| Piece             | Purpose                                                            | Reference                                                       |
| ----------------- | ------------------------------------------------------------------ | --------------------------------------------------------------- |
| Nix flake         | Share hooks, the dev shell, the package-bound library, and systems | `github:hakula139/devkit`                                       |
| Composite actions | Install Nix with the shared cache, and gate a run on its jobs      | `hakula139/devkit/actions/setup-nix@main`, `.../ci-result@main` |
| CI workflow       | Run `nix flake check` on Linux and macOS                           | `hakula139/devkit/.github/workflows/nix.yml@main`               |

## Adopt the flake

devkit needs nixpkgs 26.05 or later, since `nodeTool` pins `nodejs_26` and `pnpm_12`.

```nix
devkit = {
  url = "github:hakula139/devkit";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`devkit.lib.systems` and `devkit.lib.eachSystem` replace `flake-utils`, and `eachSystem` merges each system's attribute set, so an output that a system omits is absent there:

```nix
outputs =
  {
    devkit,
    nixpkgs,
    ...
  }:
  devkit.lib.eachSystem devkit.lib.systems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      dk = devkit.lib.mkLib pkgs;

      preCommit = dk.preCommit {
        src = ./.;
      };
    in
    {
      checks.pre-commit = preCommit.check;

      devShells.default = pkgs.mkShell {
        name = "my-tool-dev";
        packages = [ pkgs.ripgrep ];
        inputsFrom = [ preCommit.shell ];
        env.MY_VAR = "value";
      };
    }
  );
```

`devkit.lib` holds the pure helpers, and `dk = devkit.lib.mkLib pkgs` binds `pkgs` once for the rest. [Hooks](docs/hooks.md) lists the hooks and the config files they read, and covers the dev and check split, `preCommit.shell`, and the lockfile-pinned tools.

Add `/.pre-commit-config.yaml` to the repository's `.gitignore`, since the dev shell generates it.

Start the repository's `.envrc` with `# shellcheck shell=bash`, as devkit's does, since prek tags `.envrc` as a bash file and shellcheck rejects one without a shebang or shell directive.

Add a `cspell.json` that names a project dictionary, as devkit's does with `.cspell/words.txt`, since cspell otherwise rejects words such as `devkit`, `nixpkgs`, and `pkgs` above. devkit's `.editorconfig`, `.markdownlint-cli2.jsonc`, and `.prettierrc.json` are starting points for the indentation, Markdown, and Prettier hooks.

## Adopt the CI workflow and the gate

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.event.pull_request.number || github.run_id }}
  cancel-in-progress: true

jobs:
  nix:
    uses: hakula139/devkit/.github/workflows/nix.yml@main
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}

  result:
    name: CI Result
    # A skipped required check passes, so the gate must run after failures too.
    if: ${{ !cancelled() }}
    needs: [nix]
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      actions: read
    steps:
      - name: Check results
        uses: hakula139/devkit/actions/ci-result@main
```

Pass `macos: false` to the `nix` job to skip the macOS leg. The Linux leg still evaluates every system's outputs with `nix flake check --all-systems`, so leave a package out of each system its `meta.platforms` excludes. Make `CI Result` the required check in the branch ruleset, and add every new check job to its `needs`. The gate skips a job that is still running, so a job missing from `needs` that finishes after the gate starts is never checked.

Every run reads the public `hakula` Cachix cache, and `nix.yml` pushes builds to it only from the default branch. Create a `CACHIX_AUTH_TOKEN` secret to enable the push.

## Development

[`AGENTS.md`](AGENTS.md) is the contributor entry point for people and coding agents alike.

## License

Copyright (c) 2026 [Hakula](https://hakula.xyz). Licensed under the [MIT License](LICENSE).
