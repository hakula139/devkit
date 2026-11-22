# CI workflow and gate

## Set up CI

This `ci.yml` runs the shared Nix checks and reports their outcome through `CI Result`.

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
    uses: hakulab/devkit/.github/workflows/nix.yml@v3
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
        uses: hakulab/devkit/.github/actions/ci-result@v3
```

When adding checks, keep both of these settings on the gate required by the [branch ruleset].

- List every check job in its `needs` so the gate waits for each result. A job still running when the gate starts can fail after the gate has passed.
- Keep `if: ${{ !cancelled() }}` on the gate, since GitHub can otherwise skip it after an upstream failure and count the required check as passing.

## Configure reusable workflows

| Job                | What belongs here                                   | Caller configuration                                                                              |
| ------------------ | --------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [Nix]              | Flake checks and shared hooks                       | Expose packages under `checks` and include `preCommit` in the default dev shell                   |
| [Python] or [Node] | Language tests and coverage                         | Configure pytest or the package's `test` script                                                   |
| [Rust]             | Cargo tests, coverage, and optional MSRV checks     | Set `msrv: true` for the `msrv` dev shell or `all_features: true` to check every feature together |
| [Project job]      | Project builds, packaging, or native Windows checks | Use the project toolchain and upload artifacts a later job consumes                               |
| [CI Result]        | One required status for all check jobs              | Keep the job name `CI Result` and grant `actions: read`                                           |

### Choose platforms

The Nix and Rust workflows run on Linux and macOS by default, while Python and Node run on Linux unless you enable `macos: true`. Even with `macos: false`, the Linux Nix job evaluates every system's outputs with `nix flake check --all-systems`, so leave a package out of each system its `meta.platforms` excludes.

### Check out source

Use `sparse-checkout` to keep a large tracked payload out of CI's Nix store, and apply the same exclusions in local checkouts where the payload must stay out of the world-readable store. Patterns use non-cone mode, so `/*` followed by `!/payload/` excludes that directory.

Pass `submodules: true` if the build needs first-level submodules. Shared checkouts discard Git credentials, so later steps that perform authenticated Git operations must supply their own.

### Cache builds

All Nix and language jobs can read the public `hakula` Cachix cache. To publish builds from the default branch, pass `CACHIX_AUTH_TOKEN`.

### Pin store paths

To preserve a flake output through Cachix garbage collection, pin it from a checkout that contains it. Authenticate the Cachix client earlier in the job by passing `CACHIX_AUTH_TOKEN` to `setup-nix` as `cachix_auth_token`.

```yaml
- name: Pin critical store paths
  if: github.ref == 'refs/heads/main'
  uses: hakulab/devkit/.github/actions/cachix-pin@v3
  with:
    pins: '{"my-tool-main-x86_64-linux": ".#default"}'
```

If builds can finish out of order, check the current branch head before pinning so an older run cannot replace a newer pin. See the [`cachix-pin` inputs][cachix-pin].

## Run Nix checks

To build a package in CI with `nix flake check`, expose it as a check.

```nix
checks.package = self.packages.${system}.default;
```

Include the [`preCommit` shell][pre-commit] in `devShells.default` so the Linux job can run the hooks.

## Add project jobs

Keep builds, packaging, and other project-specific steps in the repository's own jobs. Run them in the default dev shell unless they need another toolchain, and name each job for the check it performs.

- Use the subject of the check as the job ID.
- For the displayed `name`, follow the subject with `Check` and append `(${{ matrix.os }})` for an OS matrix.

Keep tool flags in the tool's configuration so contributors and CI can use the same command, with `--locked` and `--frozen-lockfile` on the command line. If the project supports Windows, add a native Windows job to `CI Result`'s `needs` because those runners cannot run Nix.

A check belongs in `nix flake check` only when it runs offline, uses dependencies that Nix supplies without a hash to maintain, and needs no build cache. A language build in the sandbox starts without its usual build cache, and if Renovate changes the fetched dependencies, their fixed-output hash needs updating. `dk.nuTests` meets these conditions for the [Nushell tests], so Nushell needs no language job.

Keep a published package in `checks` when Renovate maintains its fixed-output hash. The check catches stale hashes, so [refresh the hash on the Renovate pull request][renovate-hash] before merging.

## Language jobs

Use a language job for checks that the Nix job does not already cover, and list it in `CI Result`'s `needs`. The calling job must grant `id-token: write` for Codecov OIDC even with `coverage: false`, because the reusable workflow declares that permission on the job. Use the same call pattern for Node and Rust.

Give native cold builds the full default GitHub job timeout and pass `--print-build-logs` the first time a job enters a dev shell. For Rust, build the shell before restoring the Cargo cache so progress stays visible during toolchain discovery.

### Python

```yaml
python:
  permissions:
    contents: read
    id-token: write
  uses: hakulab/devkit/.github/workflows/python.yml@v3
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

Configure the [uv interpreter] and pytest in `pyproject.toml`. To upload coverage, add `pytest-cov` to the `dev` group and name the measured package in `source`, because a bare `--cov` can miss modules that no test imports and include unrelated packages on `PYTHONPATH`.

```toml
[tool.coverage.run]
source = ["<package>"]

[tool.pytest]
minversion = "9.0"
addopts = ["--quiet", "--cov", "--cov-report=term", "--cov-report=xml"]
strict = true
testpaths = ["tests"]
```

Add `pythonpath = ["src"]` only for a `src` layout that uv does not install as a package. When a Nix package runs the tests through `pytestCheckHook`, list `pytest-cov-stub` in `nativeCheckInputs` so the `--cov` flags don't fail its build. For a PyPI package that no Nix check builds, add a job running `nix develop -c uv build`.

### Node

Define the `test` script in `package.json` and, if you upload Vitest coverage, add `@vitest/coverage-v8` to `devDependencies` and enable the `lcov` reporter in `vitest.config.ts`.

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

If the repository has a `build` script, add a job that runs `nix develop -c pnpm build`. For a published package, include a dry-run publish or pack step. Upload the output only if a later job consumes it.

### Rust

On Cargo 1.97 or later, set the warning policy in `.cargo/config.toml` so rustc, clippy, and rustdoc can deny warnings without invalidating the build cache.

```toml
[build]
warnings = "deny"
```

For `cargo llvm-cov`, add LLVM's tools to the toolchain pinned in `rust-toolchain.toml`.

```toml
[toolchain]
components = ["clippy", "llvm-tools-preview", "rustfmt"]
```

Add `cargo-llvm-cov` to the default dev shell. For the `msrv` shell, derive the rust-overlay toolchain from the workspace's `rust-version` so you only need to maintain the MSRV in one place.

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

Because `cargo llvm-cov` skips doc tests, the coverage job runs them separately with `cargo test --locked --doc`. Pass `coverage: false` for a workspace without a library target, where that command would fail.

### Coverage

If the repository does not use Codecov, pass `coverage: false` and omit the coverage settings. Codecov gates coverage through its own status checks, so an outage leaves `CI Result` passing. Pull requests from forks upload without an OIDC token because they do not receive one.

Put path filters in `codecov.yml` under `ignore`. Since each matrix leg uploads its own report, configure `codecov.yml` to hold the status check until all reports arrive. With the macOS leg enabled, `rust.yml` sends two reports.

```yaml
codecov:
  notify:
    after_n_builds: 2
```

## Deploy a Cloudflare Worker

A root Worker with a `deploy` package script can call [`workers-deploy.yml`][workers-deploy] on a default-branch push or manual dispatch. Keep Worker-specific Wrangler flags in that script.

```yaml
deploy:
  permissions:
    contents: read
  uses: hakulab/devkit/.github/workflows/workers-deploy.yml@v3
  secrets:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

For a project with its own build or deployment policy, prepare the job before calling the [`workers` action][workers-action].

1. Check out `${{ github.sha }}` and set up Nix, which the action uses to supply its own Nushell.
2. Run `nix develop -c pnpm install --frozen-lockfile` from the repository root, then download the artifact built for that commit if the job deploys one.
3. Set `CLOUDFLARE_API_TOKEN` on the Workers step, plus `CLOUDFLARE_ACCOUNT_ID` if Wrangler's configuration omits it.

```yaml
- name: Deploy
  uses: hakulab/devkit/.github/actions/workers@v3
  with:
    directory: web
    wrangler-environment: production
    d1-database: DB
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

Restrict branch jobs to the branches allowed to deploy and use one concurrency group with `queue: max` for each Worker and environment. Once the job reaches the front of the queue, the action checks that the branch still points to the event commit. It then applies any configured remote D1 migrations before running the package's `deploy` script with the selected Wrangler environment.

### Deploy and clean up pull request previews

Use separate jobs for the two events.

- **Preview** runs on `pull_request` and may consume that run's artifact. Because a build may finish after the PR closes or advances, the action checks the live PR state and head SHA inside the queue.
- **Cleanup** runs on `pull_request_target: closed`, which the repository's Actions policy must allow. It checks that the PR is still closed so a reopened PR keeps its preview. Use only the trusted event checkout and its lockfile, and never run code or consume artifacts from the PR.

Apply the same trust check and per-PR queue to both jobs, and disable workflow-level cancellation so a running deployment or cleanup can finish.

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

Use the `preview-url` and `deployment-url` outputs for PR links. Grant the corresponding write permissions and gate comments and GitHub deployment updates on `applied == 'true'`, since GitHub can record a successful environment job even when it skipped the Cloudflare operation.

[branch ruleset]: github.md#apply-the-branch-ruleset
[Nix]: ../.github/workflows/nix.yml
[Python]: ../.github/workflows/python.yml
[Node]: ../.github/workflows/node.yml
[Rust]: ../.github/workflows/rust.yml
[Project job]: #add-project-jobs
[CI Result]: ../.github/actions/ci-result/action.yml
[cachix-pin]: ../.github/actions/cachix-pin/action.yml
[pre-commit]: hooks.md#set-up-the-dev-shell
[Nushell tests]: nu-test.md
[renovate-hash]: renovate.md#refresh-nix-dependency-hashes
[uv interpreter]: hooks.md#declare-uv
[workers-deploy]: ../.github/workflows/workers-deploy.yml
[workers-action]: ../.github/actions/workers/action.yml
