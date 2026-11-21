# Releasing devkit

Choose the version [below](#choose-the-version) and follow the [release skill](https://github.com/hakula139/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md). The Git tag and changelog carry devkit's version. Pass the release tag when drafting the changelog.

```bash
nix run .#changelog -- v3.4.1
```

After the [tag workflow](.github/workflows/tag.yml) publishes, verify the GitHub Release and, for a stable release, the major tag. If publication fails partway through, inspect the Release before retrying.

## Choose the version

Consumers follow the major tag without a PR, so classify each change by its effect on an existing caller and release at the highest level any change reaches.

- **Major:** An existing caller's configuration stops working or must change.

  - Removing, renaming, or newly requiring an input, secret, argument, attribute, flake output.
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

For changes that devkit's [CI](.github/workflows/ci.yml) and [release](.github/workflows/tag.yml) workflows do not exercise, watch the next consumer run and roll back if the change breaks it.

For example, to restore `v3.4.0` as the release used by `v3`, move the major tag back.

```bash
git tag -f v3 v3.4.0
git push origin refs/tags/v3 --force
```
