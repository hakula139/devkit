# GitHub conventions

Apply the shared settings with an authenticated `gh`. For private repositories, pass `--private` to `settings` and `ruleset` so the [administration helper](../scripts/github.nu) leaves vulnerability reporting and secret scanning alone and skips the ruleset. Manage any private branch protection separately.

## Apply repository settings

```bash
nix run github:hakula139/devkit/v3#github -- settings OWNER/REPO
```

Squash merges use the conventional PR title as the commit subject for git-cliff and the PR description as the commit body. Enabling automerge lets Renovate queue eligible PRs until their checks pass. Grant each workflow job the write permissions it needs. See the [repository settings](../.github/settings/repository.json) and [workflow permissions](../.github/settings/workflow-permissions.json).

Renovate uses Dependabot alerts to open security PRs outside its schedule and release-age floor. Leave Dependabot security updates disabled so only one updater handles each alert. Private vulnerability reporting provides the channel named in the shared `SECURITY.md`. The [security settings](../.github/settings/security.json) configure secret scanning.

Publish immutable releases for version tags. Keep the moving major tag free of releases so it can advance or [roll back](../RELEASING.md#roll-back).

## Apply the branch ruleset

The command creates or fully replaces the [shared ruleset](../.github/settings/rulesets/main.json). To change only required checks on a customized ruleset, update only its live `required_status_checks`.

```bash
nix run github:hakula139/devkit/v3#github -- ruleset OWNER/REPO
```

Gate repository jobs through [CI Result](ci.md). PRs can merge behind the default branch because its post-merge CI checks for conflicts between independently passing changes. Reserve the admin bypass for emergencies.

For an external check, append `CONTEXT@APP-ID` to the command, such as `codecov/patch@254`. To find Codecov's app ID, run `gh api apps/codecov --jq .id`.

## Set up the labels

Apply the [shared labels](../.github/settings/labels.json) and pass any repository-specific component names in lowercase to create `area: <component>` labels. Issues can span several areas.

```bash
nix run github:hakula139/devkit/v3#github -- labels OWNER/REPO cli parser
```

## Inherit the community files

Repositories under the same owner can use the pull request templates, issue forms, and `SECURITY.md` from the public [community repository](https://github.com/hakula139/.github) as defaults.
