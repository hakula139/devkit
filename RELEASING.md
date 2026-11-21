# Releasing devkit

[Choose the version](#choose-the-version), then follow the [release skill](https://github.com/hakulab/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md) to prepare and publish it. Since devkit records its version in the Git tag and changelog, pass the release tag when drafting the notes.

```bash
nix run .#changelog -- v3.4.1
```

Once the [tag workflow](.github/workflows/tag.yml) publishes the GitHub Release, verify it and, for a stable release, check the moving major tag. If publication fails partway through, inspect the Release before retrying.

## Choose the version

Consumers follow the major tag without a PR, so classify each change by its effect on an existing caller and choose the highest version bump the changes require.

- Bump the **major version** when an existing caller's configuration stops working or must change.
  - An input, secret, argument, attribute, or flake output is removed, renamed, or newly required.
  - The [minimum nixpkgs release](docs/flake.md) increases.
  - The `nodeToolchain` upgrades Node.js or pnpm to a new major version, which can put consumers outside their [`devEngines`](docs/hooks.md#declare-pnpm) ranges.
  - An action or reusable workflow changes in a way that can fail a caller's run for a reason other than hook findings.
  - The Renovate preset allows more updates to merge without review or changes the required merge strategy.
  - The `header` in the shared `cliff.toml` changes. With `--prepend`, an existing header is replaced only if it matches exactly.

- Use a **minor release** for the following changes, which existing callers can adopt without changing their configuration, even when new checks report findings.
  - The release introduces or tightens baseline hooks or shared hook defaults.
  - Shared repository settings or the branch ruleset become stricter or looser. A repository picks up those changes when the `github` helper reapplies them.
  - Additions qualify, as do newer tool versions that `lib` selects.

- Use a **patch release** for everything else, including fixes that preserve all existing contracts.

## Roll back

When a change affects a path that devkit's own workflows leave untested, watch the next consumer run and roll back if the change breaks it.

- [CI](.github/workflows/ci.yml) leaves the `python.yml`, `node.yml`, and `rust.yml` workflows to consumers.
- The [tag workflow](.github/workflows/tag.yml) publishes without release assets and leaves `release.yml` and `nix-cache.yml` to consumers.

Once you have approval to move the published tag, point the moving major tag back to the previous working stable release. For example, these commands restore `v3` to `v3.4.0`.

```bash
git tag -f v3 v3.4.0
git push origin refs/tags/v3 --force
```
