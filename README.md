# devkit

[![CI](https://github.com/hakula139/devkit/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/devkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![WakaTime coding time for devkit](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/04be7427-93da-43cd-8ed9-4d1f7e35987a.svg)

Shared development tooling for Hakula's repositories.

## Adopt the flake

devkit needs nixpkgs 26.05 or later.

```nix
devkit = {
  url = "github:hakula139/devkit/v1";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`devkit.lib.systems` and `devkit.lib.eachSystem` replace `flake-utils`:

- `devkit.lib.systems` lists the shared target systems.
- `devkit.lib.eachSystem` merges each system's attribute set, leaving any output that a system omits absent on that system.

```nix
outputs =
  {
    self,
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
        hooks = {
          deadnix.enable = true;
          nixfmt.enable = true;
          statix.enable = true;
        };
      };
    in
    {
      devShells.default = pkgs.mkShell {
        name = "my-tool-dev";
        packages = [
          pkgs.ripgrep
        ];
        inputsFrom = [
          preCommit.shell
        ];
      };

      checks.pre-commit = preCommit.check;
    }
  );
```

`devkit.lib` holds the pure helpers, and `dk = devkit.lib.mkLib pkgs` binds `pkgs` once for the rest. See [Hooks](docs/hooks.md) for hook setup and configuration.

Add `/.pre-commit-config.yaml` to the repository's `.gitignore`, since the dev shell generates it.

## Adopt the Nushell tooling

A Nushell repository adds its package and tests to the same attribute set:

```nix
packages.default = dk.mkNuApplication {
  pname = "my-tool";
  version = "0.1.0";
  src = ./src;
  skills = [
    ./skills/my-tool
  ];
};

checks.tests = dk.nuTests {
  src = ./.;
};
```

[Nushell test runner](docs/nu-test.md) covers `nu-test`, `nu-check`, and `nuTests`. `mkNuApplication` packages the application as follows:

- Reads its entry file from `<entry>.nu` at the `src` root, where `entry` defaults to `pname`, and installs it as `bin/<entry>` with `runtimeInputs` on its `PATH`.
- Packages the `.nu` files under `src`, leaving out `.test.nu`, `.stub.nu`, and `.testlib.nu`.
- Copies each `skills` directory to `share/skills/<basename>` through `devkit.lib.skillSource <directory>`, which drops those same suffixes from the skill.
- Sets `meta.mainProgram` to `entry` and merges any `meta` argument over it.

`mkNuApplication`, `nuTests`, and the `nu-*` tools run on `dk.nushell`, which is the consumer's `pkgs.nushell` when it is 0.116 or later, and otherwise the one from devkit's `nixpkgs-unstable` input, so `nixpkgs-unstable` must not follow a stable nixpkgs.

`devkit.lib` also provides the skill option and links for a Home Manager module:

```nix
options.programs.my-tool.skillDirectories = lib.mkOption devkit.lib.skillDirectoriesOption;

config = lib.mkIf cfg.enable {
  home.packages = [
    cfg.package
  ];
  home.file = devkit.lib.skillLinks {
    inherit (cfg) package;
    name = "my-tool";
    directories = cfg.skillDirectories;
  };
};
```

A skill link's `name` must equal its skill directory's basename.

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
    uses: hakula139/devkit/.github/workflows/nix.yml@v1
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
        uses: hakula139/devkit/actions/ci-result@v1
```

Pass `macos: false` to the `nix` job to skip the macOS leg. The Linux leg still evaluates every system's outputs with `nix flake check --all-systems`, so leave a package out of each system its `meta.platforms` excludes.

`nix.yml` runs only `nix flake check`, which builds only the `checks` outputs, not `packages`, so expose the package as a check to have CI build it:

```nix
checks.package = self.packages.${system}.default;
```

The [branch ruleset](docs/github.md#apply-the-branch-ruleset) requires `CI Result`, so add every new check job to its `needs`. The gate skips any job that is still running, so a job missing from `needs` that finishes after the gate starts is never checked.

Every run reads the public `hakula` Cachix cache, and `nix.yml` pushes builds to it only from the default branch. Create a `CACHIX_AUTH_TOKEN` secret to enable pushing.

## Adopt the release workflow

See [Releasing](docs/releasing.md) for release setup and the release procedure.

## Adopt the Renovate preset

Extend the preset from `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>hakula139/devkit"]
}
```

- `github>hakula139/devkit` picks up preset changes on the next Renovate run without waiting for a devkit release.
- `github>hakula139/devkit#v1` picks up preset changes only on a devkit release.
- `github>hakula139/devkit#v1.2.3` picks up preset changes only when you bump the reference.

The preset's merge policy requires squash merging:

- Daily lock maintenance, flake input and rust-toolchain updates, and minor and patch cargo and npm updates automerge with squash.
- Every other update opens for review.

A devkit major update opens a separate `devkit` PR that updates the `@v1` references, the `#v1` preset reference, and major-tag flake references such as `github:hakula139/devkit/v1`. Full-version references and `flake.lock` stay unchanged. Run `nix flake update devkit` on that PR before merging it.

## Adopt the GitHub conventions

See [GitHub conventions](docs/github.md) for repository defaults.

## Development

[`AGENTS.md`](AGENTS.md) is the contributor entry point for people and coding agents alike.

## License

Copyright (c) 2026 [Hakula](https://hakula.xyz). Licensed under the [MIT License](LICENSE).
