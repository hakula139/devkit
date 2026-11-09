# Releasing

devkit publishes a moving major tag. Consumers reference `@v2` for actions and workflows and `github:hakula139/devkit/v2` for the flake, so a fix reaches every repository on its next CI run or lock-maintenance PR.

## Release your repository

Use the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md) for the shared release procedure.

A repository whose two-system Nix package uses changelog-based notes can release from its own `tag.yml` by calling devkit's `release.yml`. That workflow checks the tag against the package version, waits for CI to pass on the tagged commit, pins the package in the cache, and publishes the tag's `CHANGELOG.md` section as a GitHub Release.

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
    uses: hakula139/devkit/.github/workflows/release.yml@v2
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

GitHub only lets a called workflow downgrade the caller's token, so the release job needs both permissions.

### Draft a changelog

Run the draft command from the target repository's root with an authenticated `gh`:

```bash
nix run github:hakula139/devkit/v2#changelog -- v1.2.3
```

The command uses the repository's `cliff.toml` when present and otherwise uses devkit's shared configuration. Prerelease tags automatically select the range since the previous tag. When the repository's git-cliff template supports highlights, pass a Markdown file with `--highlights <file>`.

### Recover a release

Releases that use `tagged-ci` require a passing push or dispatched run of `ci.yml` on the tagged commit. Rerun failed CI jobs or dispatch `gh workflow run ci.yml --ref v1.2.3`, then rerun the failed release jobs once CI passes. Other workflows must satisfy their own validation gates before publication.

To restore a deleted pin:

1. Check out the tag on each system it pins (`x86_64-linux` and `aarch64-darwin`).
2. Build with `nix build .#default.out --no-link --print-out-paths`.
3. Push the output with `cachix push hakula <path>` and pin it with `cachix pin hakula <repository>-<tag>-<system> <path>`.

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

    - name: Download build artifacts
      uses: actions/download-artifact@v8
      with:
        path: dist
        merge-multiple: true

    - name: Publish release
      uses: hakula139/devkit/.github/actions/publish-release@v2
      with:
        assets: |
          dist/my-tool-x86_64-linux.tar.gz
          dist/my-tool-aarch64-darwin.tar.gz
```

`assets` takes newline-separated globs relative to the repository root, and the step fails when a named file is missing or a glob matches nothing. Name each file explicitly, since a glob that matches only some archives publishes a partial set.

## Release devkit

Follow the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md), drafting with `nix run .#changelog -- v2.1.3` and skipping the version bump because devkit's packages carry no version.

Choose the release version according to the affected contract:

- **Major:** A change that requires an existing caller to change, such as removing, renaming, or newly requiring an input, secret, argument, attribute, or flake output, or raising the [minimum nixpkgs release](flake.md). Since `@v2` and `#v2` references reach callers' default branches without a PR, an action or reusable workflow change that can fail an existing caller is major too, as is a Renovate preset change that lets more updates merge without review or changes the required merge strategy. Changing the shared `cliff.toml`'s `header` requires a major release, since `--prepend` replaces an existing header only when it matches exactly.
- **Minor:** New or stricter baseline hooks or shared hook defaults. Additions and newer tool versions that `lib` selects are minor too.

### Roll back

devkit's own release never runs `release.yml`, `nix-cache.yml`, or `publish-release`'s `assets`, so after changing any of them, watch the next consumer release and roll back if it fails.

Force-move the major tag back to the previous release:

```bash
git tag -f v2 v2.1.2
git push origin refs/tags/v2 --force
```
