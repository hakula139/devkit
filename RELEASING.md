# Releasing devkit

Follow the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md), choosing a SemVer release version under [Choose the version](#choose-the-version). devkit records that version in its Git tag and changelog. The release workflow derives the npm plugin's version from the tag, replacing the manifest's `0.0.0` placeholder on the runner, so there is no release-version field to bump. Draft the changelog with:

```bash
nix run .#changelog -- v3.4.1
```

After the tagged commit passes CI, `tag.yml` publishes `@hakula139/pnpm-plugin-devkit` with provenance via GitHub OIDC, needing no npm token secret, and creates the GitHub Release in parallel. For stable releases, the moving major tag advances after both jobs succeed. npm may make the package available after the publish job finishes. Stable versions use npm's `latest` tag, and prereleases use `next`.

Verify the registry version, packed plugin, GitHub Release, and major tag after publication. If a later step fails after npm accepts the version, keep that immutable version and inspect the existing publication before retrying.

## Choose the version

Consumers follow the major tag without a PR, so classify each change by its effect on an existing caller and release at the highest level any change reaches.

- **Major:** An existing caller's configuration stops working or must change.

  - Removing, renaming, or newly requiring an input, secret, argument, attribute, or flake output.
  - Raising the [minimum nixpkgs release](docs/flake.md).
  - Raising the major version of `nodeToolchain`'s Node.js or pnpm, which fails consumers' [`devEngines`](docs/hooks.md#declare-pnpm) ranges.
  - An action or reusable workflow change that can fail a caller's run other than through hook findings.
  - A Renovate preset change that lets more updates merge without review or changes the required merge strategy.
  - Changing the shared `cliff.toml`'s `header`, since `--prepend` replaces an existing header only when it matches exactly.

- **Minor:** Callers keep working unchanged, even when new checks report findings.

  - New or stricter baseline hooks or shared hook defaults.
  - Stricter or looser shared repository settings or branch ruleset, which reach a repository only when the `github` helper reapplies them.
  - Additions and newer tool versions that `lib` selects.

- **Patch:** Everything else, such as fixes that keep every contract.

## Roll back

devkit's own release never runs `release.yml`, `nix-cache.yml`, or `publish-release`'s `assets`, and its CI never runs `python.yml`, `node.yml`, or `rust.yml`. After changing any of them, watch the next consumer run of the changed piece and roll back if it fails.

Force-move the major tag back to the previous release:

```bash
git tag -f v3 v3.4.0
git push origin refs/tags/v3 --force
```
