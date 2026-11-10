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

Every run reads the public `hakula` Cachix cache, and `nix.yml` pushes builds to it only from the default branch. Create a `CACHIX_AUTH_TOKEN` secret to enable pushing.

## Language jobs

`nix.yml` runs the hooks, so a language job runs only what no hook covers: tests, coverage, builds, MSRV, and packaging. Each job's id names its ecosystem, and its `name` is `<Ecosystem> Check`, with `(${{ matrix.os }})` appended for an OS matrix.

Jobs other than Rust's run in the default dev shell, which `nix.yml` requires to hold every hook tool and caches from the default branch. Tool flags live in the tool's configuration, so CI runs the command a contributor runs, while the lockfile assertions `--locked` and `--frozen-lockfile` stay on the command.

### Python

```yaml
python:
  name: Python Check
  runs-on: ubuntu-latest
  timeout-minutes: 30
  steps:
    - name: Checkout
      uses: actions/checkout@v7

    - name: Set up Nix
      uses: hakula139/devkit/.github/actions/setup-nix@v3

    - name: Test
      run: nix develop -c uv run --locked pytest
```

`uv run --locked` syncs the environment, so the job needs no install step. uv reads its interpreter settings from [`[tool.uv]`](hooks.md#declare-uv), and pytest reads its flags from `pyproject.toml`:

```toml
[tool.pytest]
minversion = "9.0"
addopts = ["--quiet"]
strict = true
testpaths = ["tests"]
```

Add `pythonpath = ["src"]` only for a `src` layout that uv does not install as a package. A project that publishes to PyPI adds a `nix develop -c uv build` step when no Nix check builds the package.

### Node

```yaml
node:
  name: Node Check
  runs-on: ubuntu-latest
  timeout-minutes: 30
  steps:
    - name: Checkout
      uses: actions/checkout@v7

    - name: Set up Nix
      uses: hakula139/devkit/.github/actions/setup-nix@v3

    - name: Install dependencies
      run: nix develop -c pnpm install --frozen-lockfile

    - name: Test
      run: nix develop -c pnpm test
```

`package.json` scripts carry the runner flags, and `vitest.config.ts` enables coverage. Add a `nix develop -c pnpm build` step when the repository has a `build` script, and a dry-run publish or pack step for a published package.

### Rust

Rust jobs install the toolchain named in `rust-toolchain.toml` through rustup, since Windows runners cannot run Nix:

```yaml
rust:
  name: Rust Check (${{ matrix.os }})
  runs-on: ${{ matrix.runner }}
  timeout-minutes: 30
  strategy:
    fail-fast: false
    matrix:
      include:
        - os: Linux
          runner: ubuntu-latest
        - os: macOS
          runner: macos-latest
        - os: Windows
          runner: windows-latest
  steps:
    - name: Checkout
      uses: actions/checkout@v7

    - name: Set up Rust
      run: rustup toolchain install

    - name: Cache dependencies
      uses: Swatinem/rust-cache@v2
      with:
        save-if: ${{ github.ref == 'refs/heads/main' }}

    - name: Clippy
      if: ${{ matrix.os != 'Linux' }}
      run: cargo clippy --locked --all-targets

    - name: Test
      run: cargo test --locked

msrv:
  name: MSRV Check
  runs-on: ubuntu-latest
  timeout-minutes: 30
  steps:
    - name: Checkout
      uses: actions/checkout@v7

    - name: Set up Rust
      run: rustup toolchain install

    - name: Install cargo-hack
      uses: taiki-e/install-action@cargo-hack

    - name: Cache dependencies
      uses: Swatinem/rust-cache@v2
      with:
        save-if: ${{ github.ref == 'refs/heads/main' }}

    - name: Check
      run: cargo hack check --rust-version --workspace --all-targets --locked
```

The `clippy` hook covers Linux. `.cargo/config.toml` denies warnings in rustc, clippy, and rustdoc without invalidating the build cache:

```toml
[build]
warnings = "deny"
```

For coverage, install `taiki-e/install-action@cargo-llvm-cov` and replace `cargo test --locked` with `cargo llvm-cov --locked --lcov --output-path lcov.info`. Add `--all-features` to coverage and MSRV when the crate has features.

### Sites

```yaml
site:
  name: Site Check
  runs-on: ubuntu-latest
  timeout-minutes: 30
  steps:
    - name: Checkout
      uses: actions/checkout@v7

    - name: Set up Nix
      uses: hakula139/devkit/.github/actions/setup-nix@v3

    - name: Install dependencies
      run: nix develop -c pnpm install --frozen-lockfile

    - name: Build
      run: nix develop -c pnpm build
```

Build options belong in the site's configuration or its `build` script. Upload the output with `actions/upload-artifact@v7` only when a later job downloads it.

### Nushell

`checks.tests = dk.nuTests { ... }` runs the [Nushell tests](nu-test.md) inside `nix flake check`, so Nushell needs no language job.

### Coverage

Upload each report directly after the step that writes it:

```yaml
- name: Upload to Codecov
  uses: codecov/codecov-action@v7
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
    files: lcov.info
```

- Rust writes `lcov.info`, Vitest `coverage/lcov.info`, and pytest-cov `coverage.xml` once `addopts` holds `--cov` and `--cov-report=xml`.
- Set `flags` only when the repository uploads several reports.
- `fail_ci_if_error` stays unset, so a Codecov outage or a fork pull request without the secret leaves `CI Result` passing, while Codecov's own status checks gate coverage.
- Path filters go in `codecov.yml` `ignore`, where a matrix that uploads from several legs also sets `codecov.notify.after_n_builds` to the leg count.
