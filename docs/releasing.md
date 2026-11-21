# Releasing

Consumers use devkit's moving major tag for actions, workflows, and the flake. When the tag moves, actions and workflows pick up the change on their next run, while flake consumers receive it with their next lock update. See [Releasing devkit](../RELEASING.md) for devkit's versioning and rollback policy.

## Release your repository

Follow the [release skill](https://github.com/hakulab/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md) to prepare and publish a release. If your repository publishes its default Nix package with notes from its changelog, use the shared [release workflow](../.github/workflows/release.yml) and meet these requirements before the first tag.

- Make sure `packages.default` builds on both [cache platforms](../.github/workflows/nix-cache.yml), `x86_64-linux` and `aarch64-darwin`. If you need other targets or release assets, [compose a workflow](#write-your-own-release-workflow).
- Use `packages.default.version` with a `v` prefix for the tag and without the prefix in the `CHANGELOG.md` heading, as in `## [1.2.3] - 2026-01-31`. If `.claude-plugin/plugin.json` declares a version, it must also match the package version. A tag containing `-` publishes as a prerelease.
- Run `.github/workflows/ci.yml` on default-branch pushes so it checks the exact commit you will tag.
- Supply a `CACHIX_AUTH_TOKEN` that can push and pin packages in the `hakula` Cachix cache.

Configure `.github/workflows/tag.yml` to run on pushes of version tags and group concurrent runs by workflow and ref, as in [devkit's tag workflow](../.github/workflows/tag.yml). Grant both permissions shown below to the calling job, since GitHub only lets a called workflow reduce the permissions it inherits.

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

With `gh` authenticated, run the [changelog command](../scripts/changelog.nu) from the root of the repository you are releasing. The shared template starts stable drafts after the previous stable tag and prerelease drafts after the previous version tag. You can supply your own template in the repository's `cliff.toml` and pass `--highlights <file>` whenever the template supports Markdown highlights.

```bash
nix run github:hakula139/devkit/v3#changelog -- v1.2.3
```

### Recover a release

Because pull request CI can test a merge commit, the [CI gate for tags](../.github/actions/tagged-ci/tagged-ci.jq) requires a successful push or dispatch run on the tagged commit. Rerun failed CI jobs or, if your workflow supports it, dispatch a run on the tag.

```bash
gh workflow run ci.yml --ref v1.2.3
```

Once CI passes, rerun the failed release jobs. To restore a deleted cache pin, rebuild the tagged package on the affected system, push its output to `hakula`, and pin it as `<repository>-<tag>-<system>`, following [`nix-cache.yml`](../.github/workflows/nix-cache.yml).

### Write your own release workflow

Start from the jobs in [`release.yml`](../.github/workflows/release.yml).

1. Check the version before waiting for CI so a mismatch fails immediately. Grant `actions: read` for the [`tagged-ci` action](../.github/actions/tagged-ci/action.yml) and add `contents: read` if the version check checks out the repository.
2. After CI passes, call [`nix-cache.yml`](../.github/workflows/nix-cache.yml) if the package builds on both cache platforms.
3. Make publication depend on every required build and cache pin. In the publish job, check out the tagged commit with `persist-credentials: false`, then download the build artifacts and call [`publish-release`](../.github/actions/publish-release/action.yml) with `contents: write`. List each expected asset path on its own line relative to the repository root, since a glob can match an incomplete set of archives.

### Notify a Homebrew tap

Once every publication job succeeds, call [`homebrew.yml`](../.github/workflows/homebrew.yml) on tag runs only. The workflow forwards the full tag to the tap, including any prerelease suffix.

- Pass the formula name as `formula` and the tap repository's name as `tap-repository`. The tap must have the same owner as the caller and an `update.yml` workflow on `main` that accepts `formula` and `tag`.
- Install the GitHub App on the tap with Actions write access and pass its client ID as `RELEASE_APP_ID` and its private key as `RELEASE_APP_PRIVATE_KEY`.
