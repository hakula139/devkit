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

## Refresh Nix dependency hashes

A published package that fetches its dependencies through a fixed-output derivation, such as `fetchPnpmDeps`, keeps its `checks.package`, since that check is what catches a stale hash. Opt in to `nix-update.yml` to refresh the hash on Renovate's pull requests:

1. Install the `hakula-release-bot` App on the repository with contents write access, and make its organization secrets `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` available to it. A repository that already updates its Homebrew formula with this App needs no new setup.

2. Add the job to `ci.yml`, so it shares the pull request trigger and concurrency group, and list it in `CI Result`'s `needs`:

   ```yaml
   nix-update:
     uses: hakula139/devkit/.github/workflows/nix-update.yml@v3
     secrets:
       APP_ID: ${{ secrets.RELEASE_APP_ID }}
       APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
   ```

3. Add the bot's author address to the repository's Renovate config, so Renovate keeps managing a branch that carries the refresh commit:

   ```json
   {
     "gitIgnoredAuthors": ["351352052+hakula-release-bot[bot]@users.noreply.github.com"]
   }
   ```

   The preset leaves out this address: setting it for every repository would accept a bot-authored commit on any opted-out branch and widen automerge, which is a Major preset change.

Pass `package: <attribute>` when the package is not the flake's `default`.

The job runs only for a same-repository pull request that `renovate[bot]` authored and triggered, from a `renovate/` branch, when it is opened, updated, or reopened. The gate matches the Mend-hosted `renovate[bot]` account and Renovate's default `renovate/` branch prefix. It checks out the event's head commit without persisted credentials, sets up Nix without a Cachix token, and runs `nix-update --flake --version=skip <package>`. A run without a diff pushes nothing, and a run that writes untracked files fails.

The App token is created after the Nix steps, is scoped to the repository with only `contents: write`, and so never reaches Nix code from the pull request. The push uses `--force-with-lease` on the exact checked-out commit, so a run that started before Renovate pushed again cannot overwrite the newer head.

The App's push starts an ordinary `pull_request` run, since an App token, unlike `GITHUB_TOKEN`, triggers workflows. That run skips the hash job because its actor is the App, so the refresh does not loop, and its `CI Result` gates the new head. `gitIgnoredAuthors` keeps Renovate updating the branch.

A devkit major update opens a separate `devkit` PR that updates these major-tag references:

- Action and workflow refs such as `hakula139/devkit/.github/actions/setup-nix@v3` in workflow, action, and Markdown files.
- The preset ref `github>hakula139/devkit#v3` in the Renovate config and Markdown files.
- `github:hakula139/devkit/v3` refs in `flake.nix` and Markdown files.
- `github.com/hakula139/devkit/blob/v3` and `tree/v3` links in Markdown files.

The Markdown scan skips `CHANGELOG.md` in every directory, since its entries record past releases' refs. Full-version references and `flake.lock` stay unchanged. Run `nix flake update devkit` on that PR before merging it.
