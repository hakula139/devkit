# GitHub conventions

These conventions provide defaults for public repositories, and you can extend the required checks and labels to fit each repository.

Run each command with an authenticated `gh`, passing the target repository as `OWNER/REPO`. For a private repository, pass `--private` to `settings` and `ruleset`, which then skip private vulnerability reporting, secret scanning, and the ruleset.

## Apply repository settings

Apply repository and workflow settings, security features, and immutable releases:

```bash
nix run github:hakula139/devkit/v3#github -- settings OWNER/REPO
```

### Repository and workflow settings

- **Merge methods: squash only.** The changelog is drafted from each squashed commit's conventional title.
- **Squash commit title and body: `PR_TITLE` and `PR_BODY`.** The pull request description carries the rationale into the commit body.
- **`delete_branch_on_merge`: on.**
- **`allow_auto_merge`: on.** Renovate's platform automerge merges the moment checks pass.
- **Wiki: off.** Docs live in the repository, and you can enable Projects and Discussions as needed.
- **Workflow token: read, cannot approve.** Each job requests the write permissions it needs.

The [repository settings](../.github/settings/repository.json) and [workflow permissions](../.github/settings/workflow-permissions.json) define these defaults.

### Security

- **Dependency alerts and updates:** Dependabot alerts stay on while Dependabot security updates stay off, because Renovate reads the alerts and opens the security pull requests itself, bypassing its schedule and the preset's release-age floor. One updater then gives security bumps the preset's commit types, labels, and automerge, and a repository needs no `dependabot.yml`.
- **Private vulnerability reporting:** Provides the channel named in the default `SECURITY.md`.
- **Secret scanning with push protection:** Keeps credentials out of the history.

The [security settings](../.github/settings/security.json) define the secret scanning configuration.

### Immutable releases

Once a release is published, its tag cannot move or be deleted and its assets are fixed, while its title and notes stay editable. The major tag has no release of its own, so `tag.yml` and a [rollback](releasing.md#roll-back) can still move it, and no tag ruleset is needed.

## Apply the branch ruleset

The ruleset blocks deleting and force-pushing the default branch, and requires a pull request for every change:

- Squash is the only allowed merge method, matching the [repository settings](#repository-and-workflow-settings), and the default branch history must stay linear.
- `CI Result` from GitHub Actions must pass. A pull request can merge while behind the default branch, since the default branch's own CI run catches a clash between pull requests.
- Every review thread must be resolved.
- No approval is required, and a new push dismisses earlier approvals so that each approval covers only the commits it reviewed.
- The admin role can bypass the ruleset in an emergency.

Apply [the main ruleset](../.github/settings/rulesets/main.json) to a repository:

```bash
nix run github:hakula139/devkit/v3#github -- ruleset OWNER/REPO
```

The helper replaces the repository's ruleset with the same `name` as the template, or creates one when none exists, so rerunning it picks up template changes.

To require checks that another app reports, list them after the repository as `CONTEXT@APP-ID`, taking the ID from `gh api apps/<slug> --jq .id`. For example, Codecov reports `codecov/patch` as app `254`:

```bash
nix run github:hakula139/devkit/v3#github -- ruleset OWNER/REPO codecov/patch@254
```

A check without `@APP-ID` binds to GitHub Actions. Gate the repository's own Actions jobs through `CI Result`'s `needs`, as the [CI workflow](ci.md) describes, so the ruleset keeps requiring `CI Result` alone from Actions.

## Set up the labels

Create or update the [shared labels](../.github/settings/labels.json) while preserving the repository's custom labels.

Use lowercase `area: <component>` labels for repository-defined components, and apply multiple area labels to an issue when needed. Pass component names without the prefix, or omit them to apply only the shared labels:

```bash
nix run github:hakula139/devkit/v3#github -- labels OWNER/REPO cli parser
```

## Inherit the community files

The public [`hakula139/.github`](https://github.com/hakula139/.github) repository supplies every repository's default pull request template, issue forms, and `SECURITY.md`.
