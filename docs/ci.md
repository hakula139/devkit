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

The reusable Nix and language workflows share these inputs and secrets.

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

Shared checkouts set `persist-credentials: false`, so later steps need their own credentials for authenticated Git operations.

A repository whose checkout carries a large payload passes `sparse-checkout` with patterns for `actions/checkout`. Supplied patterns use non-cone mode, so a negative pattern excludes a path, such as `/*` followed by `!/payload/`. A Git-backed flake reads tracked source files, and a full local evaluation copies them into the world-readable Nix store. A repository that must keep the payload out of the store also excludes it from its local checkout.

Pass `submodules: true` to check out first-level submodules before entering the dev shell in CI.

### Cache builds

Every run reads the public `hakula` Cachix cache. With `CACHIX_AUTH_TOKEN`, uploads happen only from the default branch.

### Pin store paths

A job that built on the default branch pins a store path so that garbage collection keeps it in `hakula`. The `cachix-pin` action builds each flake output, pushes its output, and pins it, and the job authenticates through the `cachix_auth_token` of `setup-nix`:

```yaml
- name: Pin critical store paths
  if: github.ref == 'refs/heads/main'
  uses: hakula139/devkit/.github/actions/cachix-pin@v3
  with:
    pins: ${{ toJSON(matrix.config.cachix_pins) }}
```

`pins` is a JSON object that maps each pin name to its flake output, such as `{"kiln-main-x86_64-linux": ".#kiln"}`. Each pin keeps its latest two revisions, and `keep-revisions` overrides that count. Pins run in sequence, so a job pinning an older checkout's build guards the step itself. `nix-cache.yml` pins `.#default` through this action.

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

Tool flags live in the tool's configuration, so CI runs the command a contributor runs, while `--locked` and `--frozen-lockfile` stay on the command. A project that supports Windows, whose runners cannot run Nix, adds a native Windows job to `CI Result`'s `needs`.

A check belongs in `nix flake check` only when it runs offline, on dependencies that Nix supplies without a hash to maintain, and without a build cache. The sandbox has no network, a fixed-output hash breaks on every Renovate lockfile update, and a sandbox build compiles every dependency again. `dk.nuTests` meets these for the [Nushell tests](nu-test.md), so Nushell needs no language job.

A published package whose fixed-output hash Renovate maintains is an exception, since the check catches a stale hash. Keep it in `checks`, and [refresh the hash on the Renovate pull request](renovate.md#refresh-nix-dependency-hashes) before merging.

## Language jobs

`nix.yml` runs the hooks, so a language job runs only what no hook covers. Call `python.yml`, `node.yml`, or `rust.yml` for tests, coverage, and the Rust MSRV, and list each job in `CI Result`'s `needs`. The Codecov upload authenticates with OIDC, so the calling job grants `id-token: write`, even with `coverage: false`.

Nix and language jobs use GitHub's default 360-minute job timeout to allow native cold builds, and their dev-shell entries print builder logs until the shell is built. Rust builds its default or MSRV dev shell before restoring the Cargo cache, so toolchain discovery does not hide a cold build inside the cache action.

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

A repository with a `build` script adds a job running `nix develop -c pnpm build`, with a dry-run publish or pack step for a published package. Upload the output only when a later job consumes it.

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

## Deploy a Cloudflare Worker

A Worker with its package and Wrangler configuration at the repository root can call [`workers-deploy.yml`](../.github/workflows/workers-deploy.yml). The workflow installs dependencies from `pnpm-lock.yaml` in the repository's Nix dev shell and runs the locked Wrangler.

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  deploy:
    uses: hakula139/devkit/.github/workflows/workers-deploy.yml@v3
    secrets:
      CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

Use the repository's default branch in the push filter. The workflow deploys only from that branch, serializes jobs in the `workers-production` concurrency group, and skips Wrangler if the branch has moved. Pass `minify: true` under `with` to deploy with `--minify`.

### Deploy a build artifact

A project with a separate build job can call the [`workers` action](../.github/actions/workers/action.yml) after its checks pass. Restrict deployment to the intended branches and serialize jobs that target the same Worker and Wrangler environment with a shared concurrency group and `queue: max`. Check out the event commit (`${{ github.sha }}`), set up Nix, and run `nix develop -c pnpm install --frozen-lockfile` at the repository root. Download the artifact built for that event commit in the same workflow run.

```yaml
- name: Download site
  uses: actions/download-artifact@v8
  with:
    name: site-dist
    path: web/dist/

- name: Deploy
  uses: hakula139/devkit/.github/actions/workers@v3
  with:
    directory: web
    wrangler-environment: production
    d1-database: DB
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

`directory` defaults to the repository root. Set `wrangler-environment` for a named Wrangler environment. With `d1-database` set to a Wrangler D1 binding or database name, the action checks the live branch head, applies pending remote migrations, and deploys only after they succeed. Set `CLOUDFLARE_ACCOUNT_ID` on the action step if the Wrangler configuration omits it.

### Deploy and clean up pull request previews

Run `operation: preview` on `pull_request` and `operation: cleanup` on `pull_request_target` with `types: [closed]`. The repository's [Actions event policy](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target#default-policy-for-pull_request_target) must allow cleanup. Both jobs use the same trust check, permissions, and queue.

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

Keep workflow-level cancellation disabled for runs containing either job so closing or updating a pull request cannot interrupt a running Cloudflare operation. Set up the checkout and dependencies as for a branch deployment. Preview can use the artifact built from its event commit. Cleanup runs with the trusted `pull_request_target` checkout and its lockfile. Never check out PR code or download PR artifacts during cleanup.

```yaml
- name: Deploy preview
  id: workers
  uses: hakula139/devkit/.github/actions/workers@v3
  with:
    operation: preview
    directory: web
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

Use the same Worker directory and credentials with `operation: cleanup`. The action deploys `pr-<number>` only while the PR is open at the triggering head SHA. Cleanup deletes that preview only while the PR is closed and succeeds if it is already absent.

Use `steps.workers.outputs.preview-url` for the stable PR link and `steps.workers.outputs.deployment-url` for that deployment. Gate caller steps that update comments or deactivate GitHub deployments with `if: steps.workers.outputs.applied == 'true'`. Grant `pull-requests: write` to jobs that comment and `deployments: write` to jobs that deactivate deployments. GitHub's automatic deployment records reflect job status, so a successfully skipped action can still appear as a successful deployment when its job declares an environment.
