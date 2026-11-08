# Releasing

devkit publishes a moving major tag. Consumers reference `@v1` for actions and workflows and `github:hakula139/devkit/v1` for the flake, so a fix reaches every repository on its next CI run or lock-maintenance PR.

## Release your repository

Follow [Cut a release](#cut-a-release) for the shared release procedure. A repository's local release documentation supplies:

- Version files and policy.
- Notes source.
- Validation commands.
- Workflows.
- Publishing targets.
- Recovery restrictions.

Keep those contracts in the repository and link here for the shared procedure.

A repository whose two-system Nix package uses changelog-based notes can release from its own `tag.yml` by calling devkit's `release.yml`. That workflow waits for CI to pass on the tagged commit, pins the package in the cache, and publishes the tag's `CHANGELOG.md` section as a GitHub Release.

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
  version:
    name: Check Tag Version
    runs-on: ubuntu-latest
    timeout-minutes: 5
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

  release:
    needs: version
    permissions:
      actions: read
      contents: write
    uses: hakula139/devkit/.github/workflows/release.yml@v1
    secrets:
      CACHIX_AUTH_TOKEN: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

GitHub only lets a called workflow downgrade the caller's token, so the release job needs both permissions.

### Cut a release

1. Read the repository's release contract and choose the version according to its compatibility policy.

   - Create a release branch from the current default branch.
   - Update the version files, lockfiles, fixtures, and installation references that contract requires.

2. Prepare the notes from the repository's declared source:

   - **Maintained `CHANGELOG.md`:** Run the draft script from the target repository's root, replacing `<devkit-source>` with the local devkit directory:

     ```bash
     <devkit-source>/scripts/changelog.nu v1.2.3
     ```

     The script uses the repository's `cliff.toml` when present and otherwise uses devkit's shared configuration. Prerelease tags automatically select the range since the previous tag.

   - **Generated GitHub notes or annotated-tag notes:** Prepare that source as the repository specifies without introducing a changelog solely to follow this procedure.

3. [Curate the notes](#curate-release-notes), run the repository's release checks, and open a PR titled `chore(release): vX.Y.Z`.

   If another change lands before the release PR merges, update the branch and regenerate the draft range while preserving your curation so the section includes every released change.

4. Merge the release PR after its checks pass and review is approved.

5. Get approval to publish the tag separately from approval to merge the PR.

   Tag the release PR's squash commit by SHA, since a later PR may already sit on the default branch. Use the tag type the repository requires, including its approved notes for an annotated tag:

   ```bash
   git fetch origin
   git tag v1.2.3 "$(
     gh pr view 123 \
       --json mergeCommit \
       --jq .mergeCommit.oid
   )"
   git push origin v1.2.3
   ```

6. Watch the release workflow with `gh run watch`.

   - Verify the published notes, prerelease status, and each expected artifact or registry package using the repository's checks.
   - Report the release PR and published release URLs, including any incomplete targets.

### Curate release notes

devkit's draft keeps `feat`, `fix`, `perf`, and breaking conventional commits, so use one of those types on any PR that changes what consumers see. Read the PR descriptions wherever titles leave the effect unclear.

1. Preserve the release history.

   - Add a release section only in the release PR. Fold any Unreleased section into it and delete Unreleased.
   - Prepend the draft, since regenerating the entire file drops curated sections and compare links.
   - Start a stable release from the curated prerelease sections it rolls up, preserving their entries and adding subsequent changes. Drafting solely from titles can lose wording and entries excluded by the commit filter.

2. Curate entries for users.

   - Describe only changes the PRs made, covering what users can now do, what no longer breaks, what works differently, and migration steps.
   - Merge entries for one user-visible change, preserving every PR link. Fold fixes to a feature introduced in the same release into that feature's entry.
   - Keep the main change's scope, and split a PR across entries when it has unrelated effects.
   - Group entries by their effect, keeping breaking changes under Breaking changes, and drop entries with no user-visible effect, such as CI-only or test-only fixes.
   - Order each group by user impact and preserve scope labels. Lead with highlights when warranted, curating them by the same rules.

3. Preserve the repository's changelog format and add the compare reference when its format requires one.

   - Compare a stable release with the previous stable tag and a prerelease with the previous tag. For the first release, link to its release page when there is no previous tag.
   - Keep reference definitions with their version section so extracted notes contain only that section's metadata.

When the repository's git-cliff template supports highlights, pass a Markdown file to the script:

```bash
<devkit-source>/scripts/changelog.nu v1.2.3 --highlights highlights.md
```

### Recover a release

Let in-flight publishing finish before attempting recovery, and inspect each destination to identify what already published:

- Follow the repository's immutability constraints, as registry versions and distributed tags may require a new version even when a GitHub Release can be edited.
- Get explicit approval before deleting a release or moving a published tag.
- Prefer rerunning failed jobs at the same commit when the publishing workflow supports it.

Releases that use `tagged-ci` require a passing push or dispatched run of `ci.yml` on the tagged commit. Rerun failed CI jobs or dispatch `gh workflow run ci.yml --ref v1.2.3`, then rerun the failed release jobs once CI passes. Other workflows must satisfy their own validation gates before publication.

To restore a deleted pin:

1. Check out the tag on each system it pins (`x86_64-linux` and `aarch64-darwin`).
2. Build with `nix build .#default.out --no-link --print-out-paths`.
3. Push the output with `cachix push hakula <path>` and pin it with `cachix pin hakula <repository>-<tag>-<system> <path>`.

### Write your own release workflow

A repository whose package builds on fewer systems, or whose release attaches build artifacts, calls devkit's actions from its own workflow. These jobs replace the caller's `release` job and run alongside its `version` job and its `build` job, which uploads the archives as artifacts:

```yaml
tagged-ci:
  name: Check Tagged Commit CI
  runs-on: ubuntu-latest
  timeout-minutes: 120
  permissions:
    actions: read
  steps:
    - name: Wait for CI on the tagged commit
      uses: hakula139/devkit/.github/actions/tagged-ci@v1

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
      uses: hakula139/devkit/.github/actions/publish-release@v1
      with:
        assets: |
          dist/my-tool-x86_64-linux.tar.gz
          dist/my-tool-aarch64-darwin.tar.gz
```

A repository whose package builds on fewer systems drops the `nix-cache` job and replaces it with `tagged-ci` in `publish`'s `needs`.

`assets` takes newline-separated globs relative to the repository root, and the step fails when a named file is missing or a glob matches nothing. Name each file explicitly, since a glob that matches only some archives publishes a partial set.

### Republish release notes

`publish-release` writes the release notes once. To update them after editing `CHANGELOG.md`, run the following from a checkout of the target repository with an authenticated `gh`, Nushell, and [`parse-changelog`](https://github.com/taiki-e/parse-changelog#installation) on `PATH`:

```bash
<devkit-source>/scripts/github.nu release-notes OWNER/REPO v1.2.3
```

## Release devkit

Cut a devkit release as [Cut a release](#cut-a-release) describes, drafting with `./scripts/changelog.nu v1.2.3` and skipping the version bump because devkit publishes no package.

Choose the release version according to the affected contract:

- **Major:** A change breaks an existing caller of an action, reusable workflow, script, `lib` function, or flake output, such as removing, renaming, or newly requiring an input, secret, argument, or returned attribute. Moving the shared `cliff.toml` or changing its `header` also requires a major release, since `--prepend` replaces an existing header only when it matches exactly.
- **Minor:** New or stricter baseline hooks.

### Roll back

Force-move the major tag back to the previous release:

```bash
git tag -f v1 v1.2.2
git push origin refs/tags/v1 --force
```
