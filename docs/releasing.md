# Releasing

devkit publishes a moving major tag. Consumers reference `@v1` for actions and workflows and `github:hakula139/devkit/v1` for the flake, so a fix reaches every repository on its next CI run or lock-maintenance PR.

## Release your repository

Use the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md) for the shared release procedure.

A repository whose two-system Nix package uses changelog-based notes can release from its own `tag.yml` by calling devkit's `release.yml`. That workflow checks the tag against the package version, waits for CI to pass on the tagged commit, pins the package in the cache, and publishes the tag's `CHANGELOG.md` section as a GitHub Release.

Tags containing a `-`, such as `v1.3.0-rc.1`, publish as prereleases. Before its first release, the caller needs:

- CI running from `.github/workflows/ci.yml` on pushes to the default branch, since `tagged-ci` counts only push and dispatched runs of that workflow on the tagged commit.
- `packages.default` exposing a `version` attribute and building on `x86_64-linux` and `aarch64-darwin`. A repository whose package builds on fewer systems [writes its own release workflow](#write-your-own-release-workflow).
- `CHANGELOG.md` with a section titled by the tag number without `v`, such as `## 1.2.3`.
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
    uses: hakula139/devkit/.github/workflows/release.yml@v1
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

GitHub only lets a called workflow downgrade the caller's token, so the release job needs both permissions.

### Draft a changelog

Run the draft script from the target repository's root with authenticated `gh`, Nushell, and Nix available, replacing `<devkit-source>` with the local devkit directory:

```bash
<devkit-source>/scripts/changelog.nu v1.2.3
```

The script uses the repository's `cliff.toml` when present and otherwise uses devkit's shared configuration. Prerelease tags automatically select the range since the previous tag.

When the repository's git-cliff template supports highlights, pass a Markdown file to the script:

```bash
<devkit-source>/scripts/changelog.nu v1.2.3 --highlights highlights.md
```

### Recover a release

Releases that use `tagged-ci` require a passing push or dispatched run of `ci.yml` on the tagged commit. Rerun failed CI jobs or dispatch `gh workflow run ci.yml --ref v1.2.3`, then rerun the failed release jobs once CI passes. Other workflows must satisfy their own validation gates before publication.

To restore a deleted pin:

1. Check out the tag on each system it pins (`x86_64-linux` and `aarch64-darwin`).
2. Build with `nix build .#default.out --no-link --print-out-paths`.
3. Push the output with `cachix push hakula <path>` and pin it with `cachix pin hakula <repository>-<tag>-<system> <path>`.

### Write your own release workflow

A repository whose package builds on fewer systems, or whose release attaches build artifacts, calls devkit's actions from its own workflow. These jobs replace the caller's `release` job and run alongside its `build` job, which uploads the archives as artifacts:

```yaml
tagged-ci:
  name: Check Release
  runs-on: ubuntu-latest
  timeout-minutes: 120
  permissions:
    actions: read
    contents: read
  steps:
    - name: Checkout
      uses: actions/checkout@v7

    - name: Set up Nix
      uses: hakula139/devkit/.github/actions/setup-nix@v1

    - name: Check the package version
      run: |
        version=$(nix eval --raw .#default.version)
        if [[ "v$version" != "$GITHUB_REF_NAME" ]]; then
          echo "::error::Tag $GITHUB_REF_NAME does not match the package version $version"
          exit 1
        fi

    - name: Wait for CI on the tagged commit
      uses: hakula139/devkit/.github/actions/tagged-ci@v1

nix-cache:
  needs: tagged-ci
  uses: hakula139/devkit/.github/workflows/nix-cache.yml@v1
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}

publish:
  name: Publish GitHub Release
  needs: [nix-cache, build]
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
      uses: hakula139/devkit/.github/actions/publish-release@v1
      with:
        assets: |
          dist/my-tool-x86_64-linux.tar.gz
          dist/my-tool-aarch64-darwin.tar.gz
```

A repository whose package builds on fewer systems drops the `nix-cache` job and replaces it with `tagged-ci` in `publish`'s `needs`.

`assets` takes newline-separated globs relative to the repository root, and the step fails when a named file is missing or a glob matches nothing. Name each file explicitly, since a glob that matches only some archives publishes a partial set.

### Republish release notes

Run the following from a checkout of the target repository with an authenticated `gh`, Nushell, and [`parse-changelog`](https://github.com/taiki-e/parse-changelog#installation) on `PATH`:

```bash
<devkit-source>/scripts/github.nu release-notes OWNER/REPO v1.2.3
```

## Release devkit

Follow the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md), drafting with `./scripts/changelog.nu v1.2.3` and skipping the version bump because devkit publishes no package.

Choose the release version according to the affected contract:

- **Major:** A change breaks an existing caller of an action, reusable workflow, script, `lib` function, or flake output, such as removing, renaming, or newly requiring an input, secret, argument, or returned attribute. Moving the shared `cliff.toml` or changing its `header` also requires a major release, since `--prepend` replaces an existing header only when it matches exactly.
- **Minor:** New or stricter baseline hooks, including stricter shared hook defaults.

### Roll back

Force-move the major tag back to the previous release:

```bash
git tag -f v1 v1.2.2
git push origin refs/tags/v1 --force
```
