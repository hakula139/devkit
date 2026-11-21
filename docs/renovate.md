# Renovate preset

## Use the preset

Extend the [shared preset](../default.json) in the consumer's `.github/renovate.json`.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>hakula139/devkit#v3"]
}
```

The major tag follows stable releases. Pin a full version for manual upgrades, or omit the ref to follow the default branch.

## Refresh Nix dependency hashes

Refresh fixed-output dependency hashes when an update changes the locked dependencies. For a package using `fetchPnpmDeps`, disable automerge for those updates in the consumer's `.github/renovate.json`.

```json
{
  "lockFileMaintenance": { "automerge": false },
  "packageRules": [{ "matchManagers": ["npm"], "automerge": false }]
}
```

Run `nix-update` from the flake root on the Renovate branch, substituting the package's attribute name for `default` if needed.

```bash
nix run nixpkgs#nix-update -- --flake --version=skip default
```

Review the diff, then commit the refreshed hash and merge the pull request promptly. The commit makes Renovate treat the branch as edited, so it stops updating that branch.

## Update devkit major references

Run `nix flake update devkit` on a devkit major update PR before merging so the flake lock follows the new major reference.
