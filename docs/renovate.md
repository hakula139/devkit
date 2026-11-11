# Renovate preset

## Use the preset

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

## Refresh Nix dependency hashes

A published package that fetches its dependencies through a fixed-output derivation, such as `fetchPnpmDeps`, needs its hash refreshed on every Renovate lockfile update. Add these rules to the repository's `.github/renovate.json`, so the hash-changing updates wait for review:

```json
{
  "lockFileMaintenance": { "automerge": false },
  "packageRules": [{ "matchManagers": ["npm"], "automerge": false }]
}
```

On the Renovate branch, from the flake root, pass the package's attribute name, such as `default` for `packages.<system>.default`:

```bash
nix run nixpkgs#nix-update -- --flake --version=skip <package>
```

Review the diff, then commit the refreshed hash and merge the pull request promptly. The commit makes Renovate treat the branch as edited, so it stops updating that branch.

## Update devkit major references

A devkit major update opens a separate `devkit` PR. Run `nix flake update devkit` on that PR before merging it.
