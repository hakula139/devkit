# devkit

[![CI](https://github.com/hakula139/devkit/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/devkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Shared development tooling for Hakula's repositories. This part carries the pre-commit baseline, the dev shell, the Node hook, the systems helpers, and the Nix CI job and gate. Later parts add the Nushell tooling, the release and cache workflows, and the Renovate preset.

## Contents

| Piece             | Reference                                                   |
| ----------------- | ----------------------------------------------------------- |
| Composite actions | `hakula139/devkit/actions/setup-nix@v1`, `.../ci-result@v1` |
| CI workflow       | `hakula139/devkit/.github/workflows/nix.yml@v1`             |
| Nix flake         | `github:hakula139/devkit/v1`                                |

## Adopt the Nix workflow and the gate

The caller keeps its triggers, `permissions`, `concurrency`, every other job, and the gate. Set `macos` and `build` to match the coverage the repository had before adoption, and pass `CACHIX_AUTH_TOKEN` by name.

```yaml
jobs:
  nix:
    uses: hakula139/devkit/.github/workflows/nix.yml@v1
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}

  result:
    name: CI Result
    if: ${{ !cancelled() }}
    needs: [nix]
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      actions: read
    steps:
      - uses: hakula139/devkit/actions/ci-result@v1
        with:
          check_run_id: ${{ job.check_run_id }}
```

`ci-result` judges only completed jobs, so a matrix leg cancelled before it starts fails the gate and a job still running beside it does not.

## Adopt the flake

```nix
devkit = {
  url = "github:hakula139/devkit/v1";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
};
```

```nix
preCommit = devkit.lib.preCommit {
  inherit pkgs;
  src = ./.;
  devHooks = uvHooks;
};

devShells.default = devkit.lib.mkDevShell {
  inherit pkgs preCommit;
  marker = "src/my-tool.nu";
  packages = [ pkgs.ripgrep ];
};

checks.pre-commit = preCommit.check;
```

[Hooks](docs/hooks.md) covers the dev and check split, `mkDevShell`, `nodeHook`, and the supported systems.

`lib.systems` and `lib.eachSystem` replace `flake-utils`, and an output may be absent on some systems:

```nix
outputs = { devkit, nixpkgs, ... }:
  devkit.lib.eachSystem devkit.lib.systems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.default = pkgs.hello;
    }
  );
```

## Development

[`AGENTS.md`](AGENTS.md) is the contributor entry point for people and coding agents alike.

## License

Copyright (c) 2026 [Hakula](https://hakula.xyz). Licensed under the [MIT License](LICENSE).
