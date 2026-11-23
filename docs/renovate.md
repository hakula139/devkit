# Renovate preset

## Use the preset

Extend the [shared preset](../default.json) in the consumer's `.github/renovate.json`.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>hakulab/devkit#v3"]
}
```

| Preset reference               | When consumers pick up changes                |
| ------------------------------ | --------------------------------------------- |
| `github>hakulab/devkit#v3`     | On a stable release within the selected major |
| `github>hakulab/devkit#v3.0.0` | When the consumer changes the pin             |
| `github>hakulab/devkit`        | On the next run after a default-branch change |

## Refresh Nix dependency hashes

When an update changes the locked dependencies, refresh the corresponding fixed-output hashes. If the package uses `fetchPnpmDeps`, disable automerge for those updates in the consumer's `.github/renovate.json` so you can refresh the hash before merging.

```json
{
  "lockFileMaintenance": { "automerge": false },
  "packageRules": [{ "matchManagers": ["npm"], "automerge": false }]
}
```

Run `nix-update` from the flake root on the Renovate branch, replacing `default` with the package's attribute name if needed.

```bash
nix run nixpkgs#nix-update -- --flake --version=skip default
```

Review the diff and commit the refreshed hash. Merge the pull request promptly because Renovate stops updating the branch once it sees your commit.

## Update devkit major references

The preset updates devkit references in `flake.nix` and Markdown files other than `CHANGELOG.md`. It inherits `config:recommended`'s ignored paths and also skips `**/fixtures/**`.

To exclude more paths from these updates, add them to top-level `ignorePaths` for all managers or `regex.ignorePaths` for regex managers only. Both settings replace the inherited array, so retain applicable paths from the preset and your top-level configuration alongside the additions.

Run `nix flake update devkit` on a devkit major update PR before merging so the flake lock follows the new major reference.
