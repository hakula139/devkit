# devkit

[![CI](https://github.com/hakula139/devkit/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/devkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![WakaTime coding time for devkit](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/04be7427-93da-43cd-8ed9-4d1f7e35987a.svg)

Shared development tooling for Hakula's repositories.

## Contents

| Piece             | Purpose                                                                                           | Reference                                                                                                 |
| ----------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Nix flake         | Share hooks, the dev shell, Nushell testing and packaging, the package-bound library, and systems | `github:hakula139/devkit/v1`                                                                              |
| Composite actions | Install Nix with the shared cache, gate a run, and release a version                              | `hakula139/devkit/actions/setup-nix@v1`, `.../ci-result@v1`, `.../tagged-ci@v1`, `.../publish-release@v1` |
| CI workflow       | Run `nix flake check` on Linux and macOS                                                          | `hakula139/devkit/.github/workflows/nix.yml@v1`                                                           |
| Release workflows | Check the tagged commit, pin the cache, and publish the release                                   | `hakula139/devkit/.github/workflows/release.yml@v1`, `.../nix-cache.yml@v1`                               |
| Renovate preset   | Share the update policy, release-age floors, and grouping                                         | `github>hakula139/devkit`                                                                                 |

## Adopt the flake

devkit needs nixpkgs 26.05 or later, since `nodeTool` pins `nodejs_26` and `pnpm_12`.

```nix
devkit = {
  url = "github:hakula139/devkit/v1";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`devkit.lib.systems` and `devkit.lib.eachSystem` replace `flake-utils`, and `eachSystem` merges each system's attribute set, so an output that a system omits is absent there:

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
      };
    in
    {
      checks.pre-commit = preCommit.check;

      devShells.default = pkgs.mkShell {
        name = "my-tool-dev";
        packages = [
          pkgs.ripgrep
        ];
        inputsFrom = [
          preCommit.shell
        ];
        env.MY_VAR = "value";
      };
    }
  );
```

`devkit.lib` holds the pure helpers, and `dk = devkit.lib.mkLib pkgs` binds `pkgs` once for the rest. [Hooks](docs/hooks.md) lists the hooks and the config files they read, and covers the dev and check split, `preCommit.shell`, and the lockfile-pinned tools.

- Add `/.pre-commit-config.yaml` to the repository's `.gitignore`, since the dev shell generates it.
- Start the repository's `.envrc` with `# shellcheck shell=bash`, as devkit's does, since prek tags `.envrc` as a bash file and shellcheck rejects one without a shebang or shell directive.
- Add a `cspell.json` that names a project dictionary, as devkit's does with `.cspell/words.txt`, since cspell otherwise rejects words such as `devkit`, `nixpkgs`, and `pkgs` above. devkit's `.editorconfig`, `.markdownlint-cli2.jsonc`, and `.prettierrc.json` are starting points for the indentation, Markdown, and Prettier hooks, and the workflow snippets in these docs follow that `.prettierrc.json`.

A devkit minor release can make a consumer's lock-maintenance PR fail, as [Release devkit](docs/releasing.md#release-devkit) explains.

## Adopt the Nushell tooling

A Nushell repository adds its tests and its package to the same attribute set:

```nix
checks.tests = dk.nuTests {
  src = ./.;
};

packages.default = dk.mkNuApplication {
  pname = "my-tool";
  version = "0.1.0";
  src = ./src;
  skills = [
    ./skills/my-tool
  ];
};
```

[Nushell test runner](docs/nu-test.md) covers `nu-test`, `nu-check`, and `nuTests`. `mkNuApplication` reads its entry file from `<entry>.nu` at the `src` root, where `entry` defaults to `pname`, and installs it as `bin/<entry>` with `runtimeInputs` on its `PATH`. It packages the `.nu` files under `src`, leaving out `.test.nu`, `.stub.nu`, and `.testlib.nu`, and copies each `skills` directory to `share/skills/<basename>` through `devkit.lib.skillSource <directory>`, which drops those same suffixes from the skill. It sets `meta.mainProgram` to `entry` and merges any `meta` argument over it.

`mkNuApplication`, `nuTests`, and the `nu-*` tools run on `dk.nushell`, which is the consumer's `pkgs.nushell` when it is 0.116 or later, and otherwise the one from devkit's `nixpkgs-unstable` input, so `nixpkgs-unstable` must not follow a stable nixpkgs.

The same `devkit.lib` provides the skill option and links for a Home Manager module:

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

`nix.yml` runs only `nix flake check`, which builds the `checks` outputs and not `packages`, so expose the package as a check to have CI build it:

```nix
checks.package = self.packages.${system}.default;
```

Make `CI Result` the required check in the branch ruleset, and add every new check job to its `needs`. The gate skips a job that is still running, so a job missing from `needs` that finishes after the gate starts is never checked.

Every run reads the public `hakula` Cachix cache, and `nix.yml` pushes builds to it only from the default branch. Create a `CACHIX_AUTH_TOKEN` secret to enable the push.

## Adopt the release workflow

[Releasing](docs/releasing.md) covers the release caller and its prerequisites, the tag-versus-package check, and the cache pin.

## Adopt the Renovate preset

Extend the preset from `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>hakula139/devkit"]
}
```

A preset change applies to every consumer on its next Renovate run, without a devkit release. Pin the reference to `github>hakula139/devkit#v1` to take preset changes only with a devkit release, or to `#v1.2.3` to take them when you bump the reference.

The preset automerges daily lock maintenance, flake input and rust-toolchain updates, and minor and patch cargo and npm updates, all with squash, so the repository must allow squash merging. Every other update opens for review. A devkit major arrives in the `devkit` group's own PR, which moves the `@v1` references, the `#v1` preset reference, and, through the preset's custom manager, a flake reference that pins the major tag, such as `github:hakula139/devkit/v1`. The manager leaves a full-version ref and `flake.lock` alone, so run `nix flake update devkit` on that PR before merging it.

## Development

[`AGENTS.md`](AGENTS.md) is the contributor entry point for people and coding agents alike.

## License

Copyright (c) 2026 [Hakula](https://hakula.xyz). Licensed under the [MIT License](LICENSE).
