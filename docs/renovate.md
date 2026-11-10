# Renovate preset

Extend the preset from `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>hakula139/devkit#v3"]
}
```

- `github>hakula139/devkit` picks up preset changes on the next Renovate run.
- `github>hakula139/devkit#v3` picks up preset changes only on a devkit release.
- `github>hakula139/devkit#v1.2.3` picks up preset changes only when you bump the reference.

The preset's merge policy requires squash merging:

- Daily lock maintenance, flake input and rust-toolchain updates, and minor and patch cargo and npm updates automerge with squash.
- Every other update opens for review.

A devkit major update opens a separate `devkit` PR that updates these major-tag references:

- Action and workflow refs such as `hakula139/devkit/.github/actions/setup-nix@v3` in workflow and action files.
- The preset ref `github>hakula139/devkit#v3` in the Renovate config.
- `github:hakula139/devkit/v3` refs in `flake.nix` and Markdown files.
- `github.com/hakula139/devkit/blob/v3` and `tree/v3` links in Markdown files.

The Markdown scan skips `CHANGELOG.md` in every directory, since its entries record past releases' refs. Full-version references and `flake.lock` stay unchanged. Run `nix flake update devkit` on that PR before merging it.
