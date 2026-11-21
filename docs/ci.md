# CI workflow and gate

## Set up CI

Use this `ci.yml` to call the shared Nix checks and gate them with `CI Result`.

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

List every check job in the `needs` of `CI Result` so the gate sees its final status. Keep `if: ${{ !cancelled() }}` on the gate. Otherwise GitHub can skip it after an upstream failure and count the required check as passing. See the [branch ruleset](github.md#apply-the-branch-ruleset).

## Configure reusable workflows

The workflow files declare their supported inputs, defaults, and secrets under `workflow_call`. See [Nix](../.github/workflows/nix.yml), [Python](../.github/workflows/python.yml), [Node](../.github/workflows/node.yml), and [Rust](../.github/workflows/rust.yml).

### Choose platforms

Pass `macos: false` to the `nix` job to skip the macOS leg. The Linux leg still evaluates every system's outputs with `nix flake check --all-systems`, so leave a package out of each system its `meta.platforms` excludes.

### Check out source

Use `sparse-checkout` to keep a large tracked payload out of CI's Nix store. Use the same exclusions in local checkouts where the payload must stay out of the world-readable store. Patterns use non-cone mode, so `/*` followed by `!/payload/` excludes that directory.

### Pin store paths

Pin a flake output that should survive Cachix garbage collection. Pass `CACHIX_AUTH_TOKEN` to `setup-nix` as `cachix_auth_token` earlier in the job.

```yaml
- name: Pin critical store paths
  if: github.ref == 'refs/heads/main'
  uses: hakula139/devkit/.github/actions/cachix-pin@v3
  with:
    pins: '{"my-tool-main-x86_64-linux": ".#default"}'
```

If builds can finish out of order, check the current branch head before pinning so an older run cannot replace a newer pin. See the [`cachix-pin` inputs](../.github/actions/cachix-pin/action.yml).

## Run Nix checks

Expose a package as a check to have `nix flake check` build it on CI.

```nix
checks.package = self.packages.${system}.default;
```

Include the [`preCommit` shell](hooks.md#set-up-the-dev-shell) in `devShells.default` so the Linux job can run the hooks.

## Add project jobs

Builds, packaging, and other project-specific steps go in the repository's own jobs. A job runs its commands in the default dev shell unless it needs another toolchain, and it follows these conventions:

- Its id names what it checks.
- Its `name` is that subject followed by `Check`, with `(${{ matrix.os }})` after it for an OS matrix.

Tool flags live in the tool's configuration, so CI runs the command a contributor runs, while `--locked` and `--frozen-lockfile` stay on the command. A project that supports Windows, whose runners cannot run Nix, adds a native Windows job to `CI Result`'s `needs`.

A check belongs in `nix flake check` only when it runs offline, on dependencies that Nix supplies without a hash to maintain, and without a build cache. The sandbox has no network, a fixed-output hash breaks on every Renovate lockfile update, and a sandbox build compiles every dependency again. `dk.nuTests` meets these for the [Nushell tests](nu-test.md), so Nushell needs no language job.

A published package whose fixed-output hash Renovate maintains is an exception, since the check catches a stale hash. Keep it in `checks`, and [refresh the hash on the Renovate pull request](renovate.md#refresh-nix-dependency-hashes) before merging.

## Language jobs

Use a language job for checks the Nix job does not already cover, and list it in `CI Result`'s `needs`. The calling job must grant `id-token: write` for Codecov OIDC even with `coverage: false`, since the reusable workflow declares that permission on the job. Use the same call pattern for Node and Rust.

Allow time for native cold builds. Build the Rust dev shell before restoring the Cargo cache so toolchain discovery cannot hide build progress.

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

Configure the [uv interpreter](hooks.md#declare-uv) and pytest in `pyproject.toml`. To upload coverage, add `pytest-cov` to the `dev` group and name the measured package in `source`. A bare `--cov` can miss modules no test imports and include unrelated packages on `PYTHONPATH`.

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

Define the `test` script in `package.json`. To upload Vitest coverage, add `@vitest/coverage-v8` to `devDependencies` and enable the `lcov` reporter in `vitest.config.ts`.

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

A repository with a `build` script adds a job running `nix develop -c pnpm build`, with a dry-run publish or pack step for a published package. Upload the output only when a later job consumes it.

### Rust

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

## Deploy a Cloudflare Worker

A root Worker with a `deploy` package script can call [`workers-deploy.yml`](../.github/workflows/workers-deploy.yml) on a default-branch push or manual dispatch. Keep Worker-specific Wrangler flags in that script.

```yaml
deploy:
  permissions:
    contents: read
  uses: hakula139/devkit/.github/workflows/workers-deploy.yml@v3
  secrets:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

For jobs with their own build or deployment policy, call the [`workers` action](../.github/actions/workers/action.yml) after checking out `${{ github.sha }}`, setting up Nix, running `nix develop -c pnpm install --frozen-lockfile`, and downloading any artifacts built for that commit. Set `CLOUDFLARE_API_TOKEN` on the step, plus `CLOUDFLARE_ACCOUNT_ID` if Wrangler's config omits it.

```yaml
- name: Deploy
  uses: hakula139/devkit/.github/actions/workers@v3
  with:
    directory: web
    wrangler-environment: production
    d1-database: DB
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

Restrict branch jobs to the branches allowed to deploy. Use one concurrency group with `queue: max` per Worker and environment so a deployment can finish after its D1 migrations have run.

### Deploy and clean up pull request previews

Call the same action on `pull_request` for previews and on `pull_request_target: closed` for cleanup. Use the same trust check, permissions, and queue in both jobs.

```yaml
if: >-
  github.event.pull_request.head.repo.full_name == github.repository &&
  github.event.pull_request.user.login != 'dependabot[bot]'
permissions:
  contents: read
  pull-requests: read
concurrency:
  group: preview-${{ github.event.pull_request.number }}
  queue: max
```

Disable workflow-level cancellation for both jobs. Allow `pull_request_target` in the repository's Actions event policy and run cleanup solely from the trusted event checkout and its lockfile.

Use the `preview-url` and `deployment-url` outputs for PR links. Gate comments and GitHub deployment updates on `applied == 'true'` and grant the corresponding write permissions. Jobs declaring a GitHub environment may still record a successful job that skipped the Cloudflare operation.
