# GitHub conventions

Apply the shared settings with an authenticated `gh`. For private repositories, pass `--private` to `settings` and `ruleset` so the [administration helper](../scripts/github.nu) leaves vulnerability reporting and secret scanning alone and skips the ruleset. Manage any private branch protection separately.

## Apply repository settings

```bash
nix run github:hakula139/devkit/v3#github -- settings OWNER/REPO
```

The [repository settings](../.github/settings/repository.json), [workflow permissions](../.github/settings/workflow-permissions.json), and [security settings](../.github/settings/security.json) provide the defaults.

- **Merging.** Use a conventional PR title and put the rationale in the description. Squash merges carry both into the commit that git-cliff reads. Automerge lets Renovate queue eligible PRs until checks pass. Automatic branch deletion is enabled.
- **Repository features.** Keep docs in the repository. The wiki is disabled. Enable Projects and Discussions per repository as needed.
- **Workflow permissions.** The default token is read-only and cannot approve PRs. Grant write permissions to the jobs that need them.
- **Security updates.** Enable Dependabot alerts and leave its security updates disabled. Renovate uses the alerts to open security PRs outside its schedule and release-age floor.
- **Security reporting.** On public repositories, private vulnerability reporting provides the channel named in the shared `SECURITY.md`. Enable secret scanning with push protection.
- **Releases.** Publishing an immutable release fixes its tag and assets. The title and notes remain editable. Keep the moving major tag free of releases so it can advance or [roll back](../RELEASING.md#roll-back).

## Apply the branch ruleset

The command creates or fully replaces the [shared ruleset](../.github/settings/rulesets/main.json). To change only required checks on a customized ruleset, update only its live `required_status_checks`.

```bash
nix run github:hakula139/devkit/v3#github -- ruleset OWNER/REPO
```

| Default branch rule | Policy                                                |
| ------------------- | ----------------------------------------------------- |
| History             | Squash by PR only, no force pushes or branch deletion |
| Review              | Resolve all review threads, zero approvals required   |
| New commits         | Dismiss earlier approvals                             |
| Required check      | `CI Result` from GitHub Actions                       |
| Admin bypass        | Emergencies only                                      |

Gate the repository's Actions jobs through [CI Result](ci.md). PRs may merge behind the default branch because its post-merge CI checks for conflicts between independently passing changes.

An extra check name without a suffix binds to GitHub Actions. For a check from another app, append `CONTEXT@APP-ID` to the command, such as `codecov/patch@254`. Look up the ID with `gh api apps/<slug> --jq .id`.

## Set up the labels

Apply the [shared labels](../.github/settings/labels.json) and pass any repository-specific component names in lowercase to create `area: <component>` labels. Existing labels with other names stay in place. Issues can span several areas.

```bash
nix run github:hakula139/devkit/v3#github -- labels OWNER/REPO cli parser
```

## Inherit the community files

Repositories under the same owner can use the pull request templates, issue forms, and `SECURITY.md` from the public [community repository](https://github.com/hakula139/.github) as defaults.
