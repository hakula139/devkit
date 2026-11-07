# GitHub conventions

Every Hakula repository starts from these GitHub defaults and uses no milestones.

A repository may deviate where a default does not fit it, such as requiring `codecov/patch` beside `CI Result` or keeping milestones, and explains why in its own docs. The defaults target public repositories, while a private one keeps what its plan allows, since rulesets need GitHub Pro there.

Use admin credentials, and run commands containing `{owner}` and `{repo}` from a checkout of the target repository.

## Apply the branch ruleset

The ruleset blocks deleting and force-pushing the default branch, and requires a pull request for every change:

- `CI Result` from GitHub Actions must pass on a branch that is up to date with the default branch.
- Every review thread must be resolved.
- No approval is required.
- The admin role can bypass the ruleset in an emergency.

From a devkit checkout, apply [the main ruleset](../.github/rulesets/main.json) to a repository:

```bash
bash scripts/apply-ruleset.sh OWNER/REPO
```

## Make releases immutable

Once a release is published, its tag cannot move or be deleted and its assets are fixed, while its title and notes stay editable, so [republishing notes](releasing.md#republish-release-notes) still works. The major tag, such as `v1`, has no release of its own, so `tag.yml` and a [rollback](releasing.md#roll-back) can still move it, and no tag ruleset is needed.

```bash
gh api repos/{owner}/{repo}/immutable-releases --method PUT
```

## Apply the repository settings

- **Merge methods: squash only.** The changelog is drafted from each squashed commit's conventional title.
- **Squash commit title and body: `PR_TITLE` and `PR_BODY`.** The pull request description carries the rationale into the commit body.
- **`delete_branch_on_merge`: on.**
- **`allow_auto_merge`: on.** Renovate's platform automerge merges the moment checks pass.
- **Wiki, Projects, and Discussions: off.** Docs live in the repository. A repository with a community turns Discussions on.
- **Workflow token: read, cannot approve.** Each job requests the write permissions it needs.

```bash
gh api repos/{owner}/{repo} \
  --method PATCH \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=true \
  -F has_wiki=false \
  -F has_projects=false \
  -F has_discussions=false
gh api repos/{owner}/{repo}/actions/permissions/workflow \
  --method PUT \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false
```

## Turn on the security features

- **Dependency alerts and updates:** Dependabot alerts stay on while Dependabot security updates stay off, because Renovate reads the alerts and opens the security pull requests itself, bypassing its schedule and the preset's release-age floor. One updater then gives security bumps the preset's commit types, labels, and automerge, and a repository needs no `dependabot.yml`.
- **Private vulnerability reporting:** Provides the channel named in the default `SECURITY.md`.
- **Secret scanning with push protection:** Keeps credentials out of the history.

```bash
gh api repos/{owner}/{repo}/vulnerability-alerts --method PUT
gh api repos/{owner}/{repo}/automated-security-fixes --method DELETE
gh api repos/{owner}/{repo}/private-vulnerability-reporting --method PUT
gh api repos/{owner}/{repo} \
  --method PATCH \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

## Set up the labels

The labels are GitHub's defaults that carry meaning, plus the one the Renovate preset applies:

<!-- cspell:ignore eeef -->

| Label              | Color    | Description                                 |
| ------------------ | -------- | ------------------------------------------- |
| `accessibility`    | `f143ab` | Barrier affecting people with disabilities  |
| `bug`              | `d73a4a` | Something isn't working                     |
| `dependencies`     | `0366d6` | Pull requests that update a dependency file |
| `documentation`    | `0075ca` | Improvements or additions to documentation  |
| `enhancement`      | `a2eeef` | New feature or request                      |
| `good first issue` | `7057ff` | Good for newcomers                          |
| `help wanted`      | `008672` | Extra attention is needed                   |

Labels do not mirror commit types, since a pull request's title already carries its type and the changelog groups by it. `bug`, `enhancement`, and `documentation` sort issues, which have no commit type, along with the pull requests that resolve them. Every other label is removed, including GitHub's `duplicate`, `invalid`, and `wontfix`, which the "duplicate" and "not planned" close reasons replace.

The commands create or update each label in the table, then delete every other label. Deleting a label permanently removes it from every issue and pull request.

```bash
labels=$(
  cat <<'EOF'
accessibility|f143ab|Barrier affecting people with disabilities
bug|d73a4a|Something isn't working
dependencies|0366d6|Pull requests that update a dependency file
documentation|0075ca|Improvements or additions to documentation
enhancement|a2eeef|New feature or request
good first issue|7057ff|Good for newcomers
help wanted|008672|Extra attention is needed
EOF
)
while IFS='|' read -r name color description; do
  gh label create "$name" \
    --color "$color" \
    --description "$description" \
    --force
done <<<"$labels"
gh label list \
  --limit 1000 \
  --json name \
  --jq '.[].name' \
  | grep -vxF "$(sed 's/|.*//' <<<"$labels")" \
  | while read -r name; do
    gh label delete "$name" --yes
  done
```

## Inherit the community files

The public [`hakula139/.github`](https://github.com/hakula139/.github) repository supplies every repository's default pull request template, issue forms, and `SECURITY.md`.
