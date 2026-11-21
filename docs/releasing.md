# Releasing

Consumers reference devkit's moving major tag for actions, workflows, and the flake. Actions pick up changes on the next run and flakes on the next lock update. For devkit's own versioning and rollback policy, see [Releasing devkit](../RELEASING.md).

## Release your repository

Follow the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md). Use the shared [release workflow](../.github/workflows/release.yml) when your default Nix package exposes its release version and builds on the [cache workflow's platforms](../.github/workflows/nix-cache.yml). Use the tag version without `v` for the `CHANGELOG.md` section and match the package version in `.claude-plugin/plugin.json` if that file declares one.

Call the workflow from `.github/workflows/tag.yml` on pushes of version tags, and run `.github/workflows/ci.yml` on default-branch pushes so it checks the commit you will tag. Grant the job both permissions because GitHub only lets a called workflow reduce its caller's permissions. The token needs push and pin access to the `hakula` Cachix cache.

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

Run the [changelog command](../scripts/changelog.nu) from the target repository's root with an authenticated `gh`. Pass `--highlights <file>` when the git-cliff template supports Markdown highlights.

```bash
nix run github:hakula139/devkit/v3#changelog -- v1.2.3
```

### Recover a release

Pull request CI can test a merge commit, so the [CI gate for tags](../.github/actions/tagged-ci/tagged-ci.jq) requires a successful push or dispatch run on the tagged commit. Rerun failed CI jobs, or dispatch CI on the tag if your workflow supports it.

```bash
gh workflow run ci.yml --ref v1.2.3
```

Rerun the failed release jobs after CI passes. To restore a deleted cache pin, rebuild the tagged package on the affected system and push and pin its output with the name in [`nix-cache.yml`](../.github/workflows/nix-cache.yml).

### Write your own release workflow

Use the jobs in [`release.yml`](../.github/workflows/release.yml) as a starting point for other build targets or release assets. Check the version before waiting for CI and make publication depend on all required builds and cache pins. Download build artifacts before calling [`publish-release`](../.github/actions/publish-release/action.yml). List each expected asset path explicitly, since a glob can match an incomplete set of archives.

### Notify a Homebrew tap

Call [`homebrew.yml`](../.github/workflows/homebrew.yml) only for tags, after all publication jobs succeed. The tap must be under the caller's owner, with an `update.yml` workflow on `main` accepting `formula` and `tag`. Install the GitHub App on the tap with Actions write access and pass its credentials as the workflow's named secrets.
