# Renovate preset

Extend the preset from `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>hakula139/devkit#v2"]
}
```

- `github>hakula139/devkit` picks up preset changes on the next Renovate run.
- `github>hakula139/devkit#v2` picks up preset changes only on a devkit release.
- `github>hakula139/devkit#v2.0.0` picks up preset changes only when you bump the reference.

The preset's merge policy requires squash merging:

- Daily lock maintenance, flake input and rust-toolchain updates, and minor and patch cargo and npm updates automerge with squash.
- Every other update opens for review.

A devkit major update opens a separate `devkit` PR that updates the `@v2` references, the `#v2` preset reference, and major-tag flake references such as `github:hakula139/devkit/v2`. Full-version references and `flake.lock` stay unchanged. Run `nix flake update devkit` on that PR before merging it.
