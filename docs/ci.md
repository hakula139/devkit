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

The [branch ruleset][branch-ruleset] requires `CI Result`, so add every new check job to its `needs`. The gate skips any job that is still running, so a job missing from `needs` that finishes after the gate starts is never checked.

Every run reads the public `hakula` Cachix cache, and `nix.yml` pushes builds to it only from the default branch. Create a `CACHIX_AUTH_TOKEN` secret to enable pushing.

[branch-ruleset]: github.md#apply-the-branch-ruleset
