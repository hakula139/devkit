# Releasing

devkit publishes a moving major tag. Consumers reference `@v1` for actions and workflows and `github:hakula139/devkit/v1` for the flake, so a fix reaches every repository on its next CI run or lock-maintenance PR.

## Release your repository

A repository releases from its own `tag.yml`, which calls devkit's `release.yml`. That workflow waits for CI to pass on the tagged commit, pins the package in the cache, and publishes the tag's `CHANGELOG.md` section as a GitHub Release, marking it as a prerelease when the tag contains a `-`, such as `v1.3.0-rc.1`. The repository needs these before its first release:

- CI runs from `.github/workflows/ci.yml` on pushes to the default branch, since `tagged-ci` counts only push and dispatched runs of that workflow on the tagged commit.
- `packages.default` exposes a `version` attribute, and it builds on `x86_64-linux` and `aarch64-darwin`. A repository whose package builds on fewer systems [writes its own release workflow](#write-your-own-release-workflow).
- `CHANGELOG.md` has a section titled with the tag number without `v`, such as `## 1.2.3`.
- The `CACHIX_AUTH_TOKEN` secret can push and pin the `hakula` Cachix cache.

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
  version:
    name: Check Tag Version
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Set up Nix
        uses: hakula139/devkit/actions/setup-nix@v1

      - name: Check the package version
        run: |
          version=$(nix eval --raw .#default.version)
          if [[ "v$version" != "$GITHUB_REF_NAME" ]]; then
            echo "::error::Tag $GITHUB_REF_NAME does not match the package version $version"
            exit 1
          fi

  release:
    needs: version
    permissions:
      actions: read
      contents: write
    uses: hakula139/devkit/.github/workflows/release.yml@v1
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

GitHub only lets a called workflow downgrade the caller's token, so the release job needs both permissions. The concurrency group stops a tag pushed again from racing the earlier run's release.

### Cut a release

1. Bump the package version to the release number, and draft the release section in `CHANGELOG.md` with devkit's shared git-cliff config:

   ```bash
   nix run nixpkgs#git-cliff -- \
     --config-url https://raw.githubusercontent.com/hakula139/devkit/v1/cliff.toml \
     --unreleased \
     --tag v1.2.3 \
     --prepend CHANGELOG.md
   ```

   The draft keeps `feat`, `fix`, `perf`, and any `!` title, so a PR that changes what consumers see uses one of those types. git-cliff counts the commits it skips, and `-vv` lists them.

   A stable section covers its prereleases. For a prerelease such as `v1.3.0-rc.2`, add `--tag-pattern '^v[0-9]'` so the section starts at the previous tag of any kind.

   Edit the draft for users, stating what changed and what a consumer must do, and lift migration notes from the PR descriptions. Only the release PR edits `CHANGELOG.md`. Fold any Unreleased section into the draft and delete it.

2. Merge the release PR.

3. Tag the release PR's squash commit by SHA, since a later PR may already sit on `main`:

   ```bash
   git fetch origin
   git tag v1.2.3 "$(
     gh pr view 123 \
       --json mergeCommit \
       --jq .mergeCommit.oid
   )"
   git push origin v1.2.3
   ```

If the tagged commit has no passing push or dispatched CI run, rerun its failed CI jobs or dispatch a run with `gh workflow run ci.yml --ref v1.2.3`, then rerun the failed release jobs once it passes.

To restore a deleted pin, check out the tag on each system it pins (`x86_64-linux` and `aarch64-darwin`) and run `nix build .#default.out --no-link --print-out-paths`, then `cachix push hakula <path>` and `cachix pin hakula <repository>-<tag>-<system> <path>`.

### Write your own release workflow

A repository whose package builds on fewer systems, or whose release attaches build artifacts, calls devkit's actions from its own workflow. These jobs replace the caller's `release` job and run alongside its `version` job and its own `build` job, which uploads the archives as artifacts:

```yaml
tagged-ci:
  name: Check Tagged Commit CI
  runs-on: ubuntu-latest
  timeout-minutes: 120
  permissions:
    actions: read
  steps:
    - name: Wait for CI on the tagged commit
      uses: hakula139/devkit/actions/tagged-ci@v1

nix-cache:
  needs: tagged-ci
  uses: hakula139/devkit/.github/workflows/nix-cache.yml@v1
  secrets:
    CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}

publish:
  name: Publish GitHub Release
  needs: [version, nix-cache, build]
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
      uses: hakula139/devkit/actions/publish-release@v1
      with:
        assets: |
          dist/my-tool-x86_64-linux.tar.gz
          dist/my-tool-aarch64-darwin.tar.gz
```

A repository whose package builds on fewer systems drops the `nix-cache` job and replaces it with `tagged-ci` in `publish`'s `needs`.

`assets` takes newline-separated globs relative to the repository root. The step fails when a named file is missing or a glob matches nothing. Name each file, since a glob that matches only some archives publishes a partial set.

### Republish release notes

`publish-release` writes the notes once. To refresh them from an edited `CHANGELOG.md`, fetch `parse-changelog` and edit the release only if parsing succeeds. Replace `x86_64-unknown-linux-musl` below with your system's target, such as `aarch64-apple-darwin` on a Mac:

```bash
dir=$(mktemp -d)
gh release download \
  -R taiki-e/parse-changelog \
  -p 'parse-changelog-x86_64-unknown-linux-musl.tar.gz' \
  --dir "$dir"
tar -xzf "$dir"/parse-changelog-*.tar.gz -C "$dir"
"$dir/parse-changelog" CHANGELOG.md 1.2.3 >"$dir/notes.md" \
  && gh release edit v1.2.3 --notes-file "$dir/notes.md"
```

## Release devkit

Cut a devkit release as [Cut a release](#cut-a-release) describes, but skip the version bump, since devkit publishes no package, and run step 1's command without `--config-url` so git-cliff reads the `cliff.toml` shipped in the release. Its `tag.yml` runs `tagged-ci` and `publish-release` directly without pinning anything in the cache.

Moving the major tag requires the `hakula-release-bot` GitHub App, installed on the repository with Contents and Workflows write permissions. Its client ID and private key live in the `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` secrets, and `tag.yml` mints a token from them with `actions/create-github-app-token` for the push.

Any change that breaks an existing caller of an action, a reusable workflow, a `lib` function, or a flake output, such as removing, renaming, or newly requiring an input, secret, argument, or returned attribute, requires a new major tag. Moving the shared `cliff.toml` or changing its `header` also requires one, since `--prepend` replaces an existing header only when it matches exactly. A new or stricter baseline hook ships in a minor release even when it reports findings, so each consumer's lock-maintenance PR fails until its findings are fixed on the Renovate branch.

### Roll back

Force-move the major tag back to the previous release:

```bash
git tag -f v1 v1.2.2
git push origin refs/tags/v1 --force
```
