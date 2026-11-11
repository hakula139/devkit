# CI workflow and gate

## Set up CI

A repository's `ci.yml` calls the shared workflows and gates them with `CI Result`:

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
    uses: hakula139/devkit/.github/workflows/nix.yml@v3
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
      - name: Check results
        uses: hakula139/devkit/.github/actions/ci-result@v3
```

The [branch ruleset](github.md#apply-the-branch-ruleset) requires `CI Result`, so add every new check job to its `needs`. The gate skips any job that is still running, so a job missing from `needs` that finishes after the gate starts is never checked. `CI Result` runs after a failed job as well, since a skipped required check passes.

## Configure reusable workflows

The reusable workflows share these inputs and secrets.

| Input             | Workflows                            | Default                                          | Effect                                                |
| ----------------- | ------------------------------------ | ------------------------------------------------ | ----------------------------------------------------- |
| `coverage`        | `python.yml`, `node.yml`, `rust.yml` | `true`                                           | Uploads test coverage to Codecov                      |
| `macos`           | All                                  | `true` in `nix.yml` and `rust.yml`, else `false` | Adds the macOS leg                                    |
| `msrv`            | `rust.yml`                           | `false`                                          | Adds the `MSRV Check` job                             |
| `all_features`    | `rust.yml`                           | `false`                                          | Passes `--all-features` to Cargo                      |
| `sparse-checkout` | All                                  | empty                                            | Passes sparse-checkout patterns to `actions/checkout` |
| `submodules`      | All                                  | `false`                                          | Checks out first-level submodules                     |

| Secret              | Workflows | Required | Purpose              |
| ------------------- | --------- | -------- | -------------------- |
| `CACHIX_AUTH_TOKEN` | All       | No       | Uploads to the cache |

### Choose platforms

Pass `macos: false` to the `nix` job to skip the macOS leg. The Linux leg still evaluates every system's outputs with `nix flake check --all-systems`, so leave a package out of each system its `meta.platforms` excludes.

### Check out source

A repository whose checkout carries a large payload passes `sparse-checkout` with patterns for `actions/checkout`. Supplied patterns use non-cone mode, so a negative pattern excludes a path, such as `/*` followed by `!/payload/`. A Git-backed flake reads tracked source files, and a full local evaluation copies them into the world-readable Nix store. A repository that must keep the payload out of the store also excludes it from its local checkout.

Pass `submodules: true` to check out first-level submodules before entering the dev shell in CI.

### Cache builds

Every run reads the public `hakula` Cachix cache. With `CACHIX_AUTH_TOKEN`, uploads happen only from the default branch.

## Run Nix checks

`nix.yml` runs `nix flake check` on each leg, which builds only the `checks` outputs, so expose the package as a check to have CI build it:

```nix
checks.package = self.packages.${system}.default;
```

The Linux leg then runs `nix develop -c run-hooks`, and the macOS leg enters the dev shell to build the darwin hook tools, so `devShells.default` must include the [`preCommit` shell](hooks.md#set-up-the-dev-shell).

## Add project jobs

Builds, packaging, and other project-specific steps go in the repository's own jobs. A job runs its commands in the default dev shell unless it needs another toolchain, and it follows these conventions:

- Its id names what it checks.
- Its `name` is that subject followed by `Check`, with `(${{ matrix.os }})` after it for an OS matrix.
- A blank line separates its settings from its `steps`.

Tool flags live in the tool's configuration, so CI runs the command a contributor runs, while `--locked` and `--frozen-lockfile` stay on the command. A project that supports Windows, whose runners cannot run Nix, adds a native Windows job to `CI Result`'s `needs`.

A check belongs in `nix flake check` only when it runs offline, on dependencies that Nix supplies without a hash to maintain, and without a build cache. The sandbox has no network, a fixed-output hash breaks on every Renovate lockfile update, and a sandbox build compiles every dependency again. `dk.nuTests` meets these for the [Nushell tests](nu-test.md), so Nushell needs no language job.

A published package whose fixed-output hash Renovate maintains stays in `checks`, since the check catches a stale hash, and [refreshes the hash on Renovate pull requests](renovate.md#refresh-nix-dependency-hashes).

## Language jobs

`nix.yml` runs the hooks, so a language job runs only what no hook covers. Call `python.yml`, `node.yml`, or `rust.yml` for tests, coverage, and the Rust MSRV, and list each job in `CI Result`'s `needs`. The Codecov upload authenticates with OIDC, so the calling job grants `id-token: write`, even with `coverage: false`.

### Python

```yaml
python:
  permissions:
    contents: read
    id-token: write
  uses: hakula139/devkit/.github/workflows/python.yml@v3
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

The job runs `uv run --locked pytest` with the interpreter settings from [`[tool.uv]`](hooks.md#declare-uv). pytest reads its flags from `pyproject.toml`, where `--cov` needs `pytest-cov` in the `dev` group, and `source` must name the measured package or directory, since a bare `--cov` measures whatever the dev shell puts on `PYTHONPATH` and misses modules no test imports:

```toml
[tool.coverage.run]
source = ["<package>"]

[tool.pytest]
minversion = "9.0"
addopts = ["--quiet", "--cov", "--cov-report=term", "--cov-report=xml"]
strict = true
testpaths = ["tests"]
```

Add `pythonpath = ["src"]` only for a `src` layout that uv does not install as a package. A Nix package that runs the tests through `pytestCheckHook` lists `pytest-cov-stub` in `nativeCheckInputs`, so the `--cov` flags don't fail its build. A PyPI package adds a job running `nix develop -c uv build` when no Nix check builds it.

### Node

```yaml
node:
  permissions:
    contents: read
    id-token: write
  uses: hakula139/devkit/.github/workflows/node.yml@v3
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

The job runs `pnpm install --frozen-lockfile` and `pnpm test`, whose runner flags live in `package.json` scripts. `vitest.config.ts` turns on coverage with an lcov report, which needs `@vitest/coverage-v8` in `devDependencies`:

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      enabled: true,
      reporter: ['text', 'lcov'],
    },
  },
});
```

A repository with a `build` script adds a job running `nix develop -c pnpm build`, with a dry-run publish or pack step for a published package. For a static site, that job is `site` (`Site Check`) with a `Build site` step, and it uploads the output with `actions/upload-artifact@v7` only when a later job downloads it. Build options belong in the site's configuration or its `build` script.

### Rust

```yaml
rust:
  permissions:
    contents: read
    id-token: write
  uses: hakula139/devkit/.github/workflows/rust.yml@v3
  with:
    msrv: true
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

On Cargo 1.97 or later, `.cargo/config.toml` denies warnings in rustc, clippy, and rustdoc without invalidating the build cache:

```toml
[build]
warnings = "deny"
```

`cargo llvm-cov` needs LLVM's tools in the toolchain that `rust-toolchain.toml` pins:

```toml
[toolchain]
components = ["clippy", "llvm-tools-preview", "rustfmt"]
```

The default dev shell adds `cargo-llvm-cov`, and the `msrv` dev shell builds rust-overlay's toolchain at the workspace's `rust-version`, so the MSRV has one home:

```nix
let
  rustBin = rust-overlay.lib.mkRustBin { } pkgs;
  rustToolchain = rustBin.fromRustupToolchainFile ./rust-toolchain.toml;
  rustVersion = (lib.importTOML ./Cargo.toml).workspace.package.rust-version;
in
{
  devShells.default = pkgs.mkShell {
    packages = [
      rustToolchain
      pkgs.cargo-llvm-cov
    ];
    inputsFrom = [
      preCommit
    ];
  };

  devShells.msrv = pkgs.mkShell {
    packages = [
      rustBin.stable.${lib.versions.pad 3 rustVersion}.minimal
    ];
  };
}
```

`cargo llvm-cov` skips doc tests, so with coverage the job also runs `cargo test --locked --doc`, which fails without a library target. A workspace without one passes `coverage: false`.

### Coverage

A repository without Codecov passes `coverage: false` and drops the coverage settings. A Codecov outage leaves `CI Result` passing, since Codecov's own status checks gate coverage, and a fork pull request, which gets no OIDC token, uploads without one.

Path filters go in `codecov.yml` `ignore`. Each matrix leg uploads its own report, so `codecov.yml` holds Codecov's status until every upload arrives, two for `rust.yml` with its macOS leg:

```yaml
codecov:
  notify:
    after_n_builds: 2
```
