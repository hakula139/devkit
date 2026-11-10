# CI workflow and gate

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
    # A skipped required check passes, so the gate must run after failures too.
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

Pass `macos: false` to the `nix` job to skip the macOS leg. The Linux leg still evaluates every system's outputs with `nix flake check --all-systems`, so leave a package out of each system its `meta.platforms` excludes.

`nix.yml` runs `nix flake check` on each leg, which builds only the `checks` outputs, so expose the package as a check to have CI build it:

```nix
checks.package = self.packages.${system}.default;
```

The Linux leg then runs `nix develop -c run-hooks`, and the macOS leg enters the dev shell to build the darwin hook tools, so `devShells.default` must include the [`preCommit` shell](hooks.md#set-up-the-dev-shell).

The [branch ruleset](github.md#apply-the-branch-ruleset) requires `CI Result`, so add every new check job to its `needs`. The gate skips any job that is still running, so a job missing from `needs` that finishes after the gate starts is never checked.

Every run reads the public `hakula` Cachix cache. With a `CACHIX_AUTH_TOKEN` secret, `nix.yml` and the language workflows push builds to it from the default branch.

## Language jobs

`nix.yml` runs the hooks, so a language job runs only what no hook covers. Call `python.yml`, `node.yml`, or `rust.yml` for tests, coverage, and the Rust MSRV, and list each job in `CI Result`'s `needs`. Builds, packaging, and other project-specific steps go in the repository's own jobs.

A repository's own job runs its commands in the default dev shell unless it needs another toolchain. Its id names what it checks, its `name` is that subject followed by `Check`, with `(${{ matrix.os }})` after it for an OS matrix, and a blank line separates its settings from its `steps`.

Tool flags live in the tool's configuration, so CI runs the command a contributor runs, while `--locked` and `--frozen-lockfile` stay on the command. A project that supports Windows, whose runners cannot run Nix, adds a native Windows job to `CI Result`'s `needs`.

A check belongs in `nix flake check` only when it runs offline, on dependencies that Nix supplies without a hash to maintain, and without a build cache. The sandbox has no network, a fixed-output hash breaks on every Renovate lockfile update, and a sandbox build compiles every dependency again. `dk.nuTests` meets these for the [Nushell tests](nu-test.md), so Nushell needs no language job.

| Input          | Workflows  | Default                            | Effect                           |
| -------------- | ---------- | ---------------------------------- | -------------------------------- |
| `coverage`     | All        | `true`                             | Uploads test coverage to Codecov |
| `macos`        | All        | `true` in `rust.yml`, else `false` | Adds the macOS leg               |
| `msrv`         | `rust.yml` | `false`                            | Adds the `MSRV Check` job        |
| `all_features` | `rust.yml` | `false`                            | Passes `--all-features` to Cargo |

| Secret              | Workflows | Required | Purpose                             |
| ------------------- | --------- | -------- | ----------------------------------- |
| `CACHIX_AUTH_TOKEN` | All       | No       | Pushes builds to the `hakula` cache |

The Codecov upload authenticates with OIDC, so the calling job grants `id-token: write`, even with `coverage: false`.

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
