# Releasing

Consumers reference devkit's moving major tag for actions, workflows, and the flake. Actions pick up changes on the next run and flakes on the next lock update. For devkit's own versioning and rollback policy, see [Releasing devkit](../RELEASING.md).

## Release your repository

Follow the [release skill](https://github.com/hakulab/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md). For a default Nix package with changelog-based release notes, use the shared [release workflow](../.github/workflows/release.yml). Check these requirements before the first tag.

- **Builds.** `packages.default` must build on both [cache platforms](../.github/workflows/nix-cache.yml), `x86_64-linux` and `aarch64-darwin`. For other targets or release assets, [compose a workflow](#write-your-own-release-workflow).
- **Version and notes.** Tag `packages.default.version` with a `v` prefix and title the `CHANGELOG.md` section with the version alone, as in `## [1.2.3] - 2026-01-31`. If `.claude-plugin/plugin.json` declares a version, match the package version there too. A tag containing `-` publishes as a prerelease.
- **CI.** Run `.github/workflows/ci.yml` on default-branch pushes so it checks the exact commit you will tag.
- **Cache.** Supply `CACHIX_AUTH_TOKEN` with push and pin access to the `hakula` Cachix cache.

In `.github/workflows/tag.yml`, trigger on version tag pushes and group concurrent runs by workflow and ref, as in [devkit's tag workflow](../.github/workflows/tag.yml). Grant the calling job both permissions because GitHub only lets the called workflow reduce them.

```yaml
jobs:
  release:
    permissions:
      actions: read
      contents: write
    uses: hakula139/devkit/.github/workflows/release.yml@v3
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

### Draft a changelog

Run the [changelog command](../scripts/changelog.nu) from the target repository's root with an authenticated `gh`. With the shared template, stable drafts start after the previous stable tag and prerelease drafts after the previous version tag. To customize the template, supply a repository-local `cliff.toml`. Pass `--highlights <file>` when the template supports Markdown highlights.

```bash
nix run github:hakula139/devkit/v3#changelog -- v1.2.3
```

### Recover a release

Pull request CI can test a merge commit, so the [CI gate for tags](../.github/actions/tagged-ci/tagged-ci.jq) requires a successful push or dispatch run on the tagged commit. Rerun failed CI jobs, or dispatch CI on the tag if your workflow supports it.

```bash
gh workflow run ci.yml --ref v1.2.3
```

Rerun the failed release jobs after CI passes. To restore a deleted cache pin, rebuild the tagged package on the affected system, push its output to `hakula`, and pin it as `<repository>-<tag>-<system>`. See [`nix-cache.yml`](../.github/workflows/nix-cache.yml).

### Write your own release workflow

Use the jobs in [`release.yml`](../.github/workflows/release.yml) as a starting point.

1. Check the version before waiting for CI, so a mismatch fails immediately. The [`tagged-ci` action](../.github/actions/tagged-ci/action.yml) needs `actions: read`. A checkout for the version check also needs `contents: read`.
2. After CI passes, call [`nix-cache.yml`](../.github/workflows/nix-cache.yml) if the package builds on both cache platforms.
3. Make publication depend on every required build and cache pin. In the publish job, check out the tagged commit with `persist-credentials: false`, then download the build artifacts and call [`publish-release`](../.github/actions/publish-release/action.yml) with `contents: write`. List each expected asset path on its own line, relative to the repository root, since a glob can match an incomplete set of archives.

### Notify a Homebrew tap

Call [`homebrew.yml`](../.github/workflows/homebrew.yml) only for tags, after all publication jobs succeed. The tap receives the full tag, including any prerelease suffix.

- Supply the formula name as `formula` and the tap repository's name as `tap-repository`. The tap must be under the caller's owner, with an `update.yml` workflow on `main` accepting `formula` and `tag`.
- Install the GitHub App on the tap with Actions write access. Pass its client ID as `RELEASE_APP_ID` and its private key as `RELEASE_APP_PRIVATE_KEY`.
