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

A published package that fetches its dependencies through a fixed-output derivation, such as `fetchPnpmDeps`, needs its hash refreshed on every Renovate lockfile update. Opt in to `nix-update.yml`: same-repository Renovate pull requests get a refresh commit whenever `nix-update` produces a tracked diff, and the new head runs ordinary CI.

### Configure the refresh job

1. Install the `hakula-release-bot` App on the repository with contents write access, and make its organization secrets `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` available to it. A repository that already updates its Homebrew formula with this App needs no new setup.

2. Add the job to `ci.yml`, and list it in `CI Result`'s `needs`:

   ```yaml
   nix-update:
     uses: hakula139/devkit/.github/workflows/nix-update.yml@v3
     secrets:
       APP_ID: ${{ secrets.RELEASE_APP_ID }}
       APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
   ```

3. Add the bot's author address to the repository's Renovate config, so Renovate keeps managing the branch that carries the refresh commit:

   ```json
   {
     "gitIgnoredAuthors": ["351352052+hakula-release-bot[bot]@users.noreply.github.com"]
   }
   ```

Pass `package: <attribute>` when the package is not the flake's `default`.

## Update devkit major references

A devkit major update opens a separate `devkit` PR. Run `nix flake update devkit` on that PR before merging it.
