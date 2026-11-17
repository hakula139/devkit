# Releasing

devkit publishes a moving major tag. Consumers reference the major tag for actions, workflows, and the flake, so a fix reaches every repository on its next CI run or lock-maintenance PR.

For devkit's own release policy, see [Releasing devkit](../RELEASING.md).

## Release your repository

Use the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md) for the shared release procedure.

A repository whose two-system Nix package uses changelog-based notes can release from its own `tag.yml` by calling devkit's `release.yml`. That workflow checks the tag against the package version, waits for CI to pass on the tagged commit, pins the package in the cache, and publishes the tag's `CHANGELOG.md` section as a GitHub Release. When `.claude-plugin/plugin.json` sets a `version`, the workflow also requires it to match the package version.

Tags containing a `-`, such as `v1.3.0-rc.1`, publish as prereleases. Before its first release, the caller needs:

- CI running from `.github/workflows/ci.yml` on pushes to the default branch, since `tagged-ci` counts only push and dispatched runs of that workflow on the tagged commit.
- `packages.default` exposing a `version` attribute and building on `x86_64-linux` and `aarch64-darwin`. A repository whose package builds on fewer systems [writes its own release workflow](#write-your-own-release-workflow).
- `CHANGELOG.md` with a section titled by the tag number without `v`, such as `## [1.2.3] - 2026-01-31`.
- The `CACHIX_AUTH_TOKEN` secret able to push and pin the `hakula` Cachix cache.

```yaml
# .github/workflows/tag.yml
name: Tag Release

on:
  push:
    tags: ['v[0-9]+.*']

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}

jobs:
  release:
    permissions:
      actions: read
      contents: write
    uses: hakula139/devkit/.github/workflows/release.yml@v3
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

GitHub only lets a called workflow downgrade the caller's token, so the release job needs both permissions.

### Draft a changelog

Run the draft command from the target repository's root with an authenticated `gh`:

```bash
nix run github:hakula139/devkit/v3#changelog -- v1.2.3
```

The command uses the repository's `cliff.toml` when present and otherwise uses devkit's shared configuration. Prerelease tags automatically select the range since the previous tag. When the repository's git-cliff template supports highlights, pass a Markdown file with `--highlights <file>`.

### Recover a release

Releases that use `tagged-ci` require a passing push or dispatched run of `ci.yml` on the tagged commit. Rerun the failed CI jobs or dispatch a run on the tag:

```bash
gh workflow run ci.yml --ref v1.2.3
```

Rerun the failed release jobs once CI passes.

To restore a deleted cache pin, rebuild the tagged package on each target system, push its output to `hakula`, and pin it as `<repository>-<tag>-<system>`.

### Write your own release workflow

A repository that `release.yml` doesn't fit composes its own `tag.yml` from devkit's pieces:

- A `tagged-ci` job running the `tagged-ci` action, which needs only `actions: read`.
- The repository's own version check before the wait, so a mismatch fails fast. It adds a checkout and `contents: read`, as in [`release.yml`](../.github/workflows/release.yml).
- A `nix-cache` job calling `nix-cache.yml` after `tagged-ci`, if the package builds on both systems.
- A publish job that needs every earlier job, including `nix-cache` when present:

```yaml
publish:
  name: Publish GitHub Release
  needs: [tagged-ci, build]
  runs-on: ubuntu-latest
  timeout-minutes: 10
  permissions:
    contents: write

  steps:
    - name: Checkout
      uses: actions/checkout@v7
      with:
        persist-credentials: false

    - name: Download build artifacts
      uses: actions/download-artifact@v8
      with:
        path: dist
        merge-multiple: true

    - name: Publish release
      uses: hakula139/devkit/.github/actions/publish-release@v3
      with:
        assets: |
          dist/my-tool-x86_64-linux.tar.gz
          dist/my-tool-aarch64-darwin.tar.gz
```

`assets` takes newline-separated globs relative to the repository root, and the step fails when a named file is missing or a glob matches nothing. Name each file explicitly, since a glob that matches only some archives publishes a partial set.

### Notify a Homebrew tap

A release workflow can notify a tap under the same owner. The tap repository must have an `update.yml` workflow on `main` that accepts `formula` and `tag` inputs. Supply its repository name as `tap-repository`, and pass a GitHub App's `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` secrets explicitly. The app must be installed on the tap with Actions write access.

The caller controls when notification runs. Require a tag and make the job depend on successful publication, including any other publication jobs the repository needs:

```yaml
homebrew:
  needs: publish
  if: github.ref_type == 'tag'
  uses: hakula139/devkit/.github/workflows/homebrew.yml@v3
  with:
    formula: my-tool
    tap-repository: homebrew-tap
  secrets:
    RELEASE_APP_ID: ${{ secrets.RELEASE_APP_ID }}
    RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```

The workflow sends the caller's tag unchanged, including prerelease suffixes.
