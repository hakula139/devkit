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

Every run reads the public `hakula` Cachix cache, and `nix.yml` and the language workflows push builds to it only from the default branch. Create a `CACHIX_AUTH_TOKEN` secret to enable pushing.

## Language jobs

`nix.yml` runs the hooks, so a language job runs only what no hook covers: tests, coverage, builds, MSRV, and packaging. `python.yml`, `node.yml`, and `rust.yml` run a language's tests and upload their coverage, and a repository adds its own job for any other step. Each job's id names what it checks, and its `name` is that subject followed by `Check`, with `(${{ matrix.os }})` after it for an OS matrix. A blank line separates a job's settings from its `steps`.

A check belongs in `nix flake check` only when it runs offline on dependencies that Nix supplies without a hash to maintain and needs no build cache, since the build sandbox has no network, a fixed-output dependency hash would break on every Renovate lockfile update, and a sandbox build compiles every dependency again on each change. `dk.nuTests` meets these for the [Nushell tests](nu-test.md), so Nushell needs no language job, while every other language's tests run in one.

Every job runs its commands in the default dev shell, which `nix.yml` requires to hold every hook tool and caches from the default branch, unless the job needs another toolchain, as the MSRV job does. Tool flags live in the tool's configuration, so CI runs the command a contributor runs, while the lockfile assertions `--locked` and `--frozen-lockfile` stay on the command. A project that supports Windows, whose runners cannot run Nix, adds a separate Windows job that installs its toolchain natively and lists it in `CI Result`'s `needs`, leaving the workflow calls unchanged.

The language workflows take the `CACHIX_AUTH_TOKEN` and `CODECOV_TOKEN` secrets and these inputs:

| Input          | Workflows  | Default                            | Effect                                                |
| -------------- | ---------- | ---------------------------------- | ----------------------------------------------------- |
| `coverage`     | All        | `true`                             | Uploads test coverage to Codecov                      |
| `macos`        | All        | `true` in `rust.yml`, else `false` | Also runs the macOS leg                               |
| `msrv`         | `rust.yml` | `false`                            | Adds the `MSRV Check` job                             |
| `all-features` | `rust.yml` | `false`                            | Passes `--all-features` to the test and MSRV commands |

### Python

```yaml
python:
  uses: hakula139/devkit/.github/workflows/python.yml@v3
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
    CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}

result:
  needs: [nix, python]
```

`python.yml` runs `uv run --locked pytest`, which syncs the environment, so the job needs no install step. uv reads its interpreter settings from [`[tool.uv]`](hooks.md#declare-uv), and pytest reads its flags from `pyproject.toml`, where `--cov` needs `pytest-cov` in the `dev` group:

```toml
[tool.pytest]
minversion = "9.0"
addopts = ["--quiet", "--cov", "--cov-report=term", "--cov-report=xml"]
strict = true
testpaths = ["tests"]
```

Add `pythonpath = ["src"]` only for a `src` layout that uv does not install as a package. A project that publishes to PyPI adds a job running `nix develop -c uv build` when no Nix check builds the package.

### Node

```yaml
node:
  uses: hakula139/devkit/.github/workflows/node.yml@v3
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
    CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}

result:
  needs: [nix, node]
```

`node.yml` runs `pnpm install --frozen-lockfile` and `pnpm test`. `package.json` scripts carry the runner flags, and `vitest.config.ts` turns on coverage and its lcov report for the upload step, and coverage needs `@vitest/coverage-v8` in `devDependencies`:

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

A repository with a `build` script adds a job that installs the dependencies and runs `nix develop -c pnpm build`, followed by a dry-run publish or pack step for a published package. A static site's build job is `site` (`Site Check`), whose last step is `Build site`. Build options belong in the site's configuration or its `build` script, and the job uploads the output with `actions/upload-artifact@v7` only when a later job downloads it.

### Rust

```yaml
rust:
  uses: hakula139/devkit/.github/workflows/rust.yml@v3
  with:
    msrv: true
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
    CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}

result:
  needs: [nix, rust]
```

`rust.yml` caches dependencies with `Swatinem/rust-cache`, runs `cargo clippy --locked --all-targets` on macOS, since the `clippy` hook covers Linux, and tests with `cargo llvm-cov --locked`. On Cargo 1.97 or later, `.cargo/config.toml` denies warnings in rustc, clippy, and rustdoc without invalidating the build cache:

```toml
[build]
warnings = "deny"
```

`cargo llvm-cov` needs LLVM's tools in the toolchain that `rust-toolchain.toml` pins:

```toml
[toolchain]
components = ["clippy", "llvm-tools-preview", "rustfmt"]
```

The default dev shell puts `cargo-llvm-cov` beside that toolchain. The `MSRV Check` job runs `cargo check --locked --workspace --all-targets` in the `msrv` dev shell, which builds rust-overlay's toolchain at the workspace's `rust-version`, so the MSRV has one home:

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

`cargo llvm-cov` skips doc tests, so the job runs `cargo test --locked --doc` after it, which fails without a library target. A workspace without a library target passes `coverage: false`, which runs `cargo test --locked` in place of both.

### Coverage

Each job uploads its report to Codecov directly after the step that writes it. A repository without Codecov passes `coverage: false` and drops the coverage settings.

- The upload leaves `fail_ci_if_error` unset, so a Codecov outage or a fork pull request without the secret leaves `CI Result` passing, while Codecov's own status checks gate coverage.
- Path filters go in `codecov.yml` `ignore`.

Each matrix leg uploads its own report, so `codecov.yml` holds Codecov's status until every upload has arrived, two for `rust.yml` with its macOS leg:

```yaml
codecov:
  notify:
    after_n_builds: 2
```
