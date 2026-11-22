# GitHub conventions

Use the [administration helper](../scripts/github.nu) with an authenticated `gh`. For a private repository, pass `--private` to both `settings` and `ruleset`. This leaves vulnerability reporting and secret scanning as configured and skips the ruleset, so manage private branch protection separately.

## Apply repository settings

```bash
nix run github:hakulab/devkit/v3#github -- settings OWNER/REPO
```

The [repository settings](../.github/settings/repository.json), [workflow permissions](../.github/settings/workflow-permissions.json), and [security settings](../.github/settings/security.json) define the defaults.

- Use a conventional **PR title** and explain the rationale in the description, since a squash merge carries both into the commit that git-cliff reads. Automerge lets Renovate queue eligible PRs until checks pass, and automatic branch deletion cleans up merged branches.
- Keep **documentation** in the repository with the wiki disabled, and enable Projects and Discussions per repository as needed.
- Grant **write permissions** to individual jobs that need them. The default workflow token is read-only and cannot approve PRs.
- Enable **Dependabot alerts** and leave Dependabot security updates disabled. Renovate uses the alerts to open security PRs without waiting for its usual update window or minimum release age.
- On public repositories, enable **private vulnerability reporting** to provide the channel named in the shared `SECURITY.md`, and enable secret scanning with push protection.
- Publishing an **immutable release** fixes its tag and assets while leaving the title and notes editable. Keep the moving major tag free of releases so it can advance or [roll back](../RELEASING.md#roll-back).

## Apply the branch ruleset

The command creates the [shared ruleset](../.github/settings/rulesets/main.json) or replaces it in full. If you only need to change the required checks on a customized ruleset, edit its live `required_status_checks` directly.

```bash
nix run github:hakulab/devkit/v3#github -- ruleset OWNER/REPO
```

| Default branch rule | Policy                                                |
| ------------------- | ----------------------------------------------------- |
| History             | Squash by PR only, no force pushes or branch deletion |
| Review              | Resolve all review threads, zero approvals required   |
| New commits         | Dismiss earlier approvals                             |
| Required check      | `CI Result` from GitHub Actions                       |
| Admin bypass        | Emergencies only                                      |

Gate the repository's Actions jobs through [CI Result](ci.md). A PR can merge even when it is behind the default branch because CI runs again after the merge to catch conflicts between changes that passed independently.

An extra check name without a suffix binds to GitHub Actions. To require a check from another app, append it to the command as `CONTEXT@APP-ID`, such as `codecov/patch@254`. You can find the app ID with `gh api apps/<slug> --jq .id`.

## Set up the labels

When applying the [shared labels](../.github/settings/labels.json), pass any repository-specific component names in lowercase to create `area: <component>` labels. The command preserves existing labels with other names, and you can apply several area labels to an issue that spans multiple components.

```bash
nix run github:hakulab/devkit/v3#github -- labels OWNER/REPO cli parser
```

## Inherit the community files

Repositories under the same owner can use the pull request templates, issue forms, and `SECURITY.md` from the public [community repository](https://github.com/hakulab/.github) as defaults.
