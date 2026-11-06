# GitHub conventions

Every Hakula repository starts from these GitHub defaults. A repository may deviate where a default does not fit it, such as requiring `codecov/patch` beside `CI Result` or keeping milestones, and says why in its own docs. The defaults target public repositories, while a private one keeps what its plan allows, since rulesets need GitHub Pro there.

Run the commands from a checkout of the repository with an admin's credentials, since `gh` fills `{owner}` and `{repo}` from the checkout.

## Apply the branch ruleset

The ruleset blocks deleting and force-pushing the default branch, and merges every change through a squashed pull request:

- `CI Result` must pass on a branch that is up to date with the default branch. A personal account has no merge queue, so the up-to-date check is the only guard against two green pull requests breaking the default branch together. Every check job joins the gate's `needs`, so the one required name survives job renames.
- Every review thread must be resolved, so an unaddressed comment blocks the merge.
- No approval is required, since a sole maintainer cannot approve their own pull request.
- The admin role can bypass the ruleset in an emergency.

```bash
gh api repos/{owner}/{repo}/rulesets \
  --method POST \
  --input - \
  <<'EOF'
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ],
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {
            "context": "CI Result",
            "integration_id": 15368
          }
        ]
      }
    }
  ]
}
EOF
```

Actor 5 is the admin repository role, and integration 15368 is GitHub Actions, so a status of the same name from another app does not satisfy the check.

## Make releases immutable

Once a release is published, its tag cannot move or be deleted and its assets are fixed, while its title and notes stay editable, so [republishing notes](releasing.md#republish-release-notes) still works. The major tag, such as `v1`, has no release of its own, so `tag.yml` and a [rollback](releasing.md#roll-back) can still move it, and no tag ruleset is needed.

```bash
gh api repos/{owner}/{repo}/immutable-releases --method PUT
```

## Apply the repository settings

| Setting                      | Value                    | Reason                                                                                        |
| ---------------------------- | ------------------------ | --------------------------------------------------------------------------------------------- |
| Merge methods                | Squash only              | Each pull request becomes one commit whose conventional title the changelog reads.            |
| Squash commit title and body | `PR_TITLE` and `PR_BODY` | The pull request description carries the rationale into the commit body.                      |
| `delete_branch_on_merge`     | On                       | A merged branch has nothing left to keep.                                                     |
| `allow_auto_merge`           | On                       | Renovate's platform automerge merges the moment checks pass.                                  |
| `allow_update_branch`        | Off                      | A branch behind the default branch is rebased onto it, and Renovate rebases its own branches. |
| Wiki, Projects, Discussions  | Off                      | Docs live in the repository. A repository with a community turns Discussions on.              |
| Workflow token               | Read, cannot approve     | Each job requests the writes it needs.                                                        |

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
  -F allow_update_branch=false \
  -F has_wiki=false \
  -F has_projects=false \
  -F has_discussions=false
gh api repos/{owner}/{repo}/actions/permissions/workflow \
  --method PUT \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false
```

## Turn on the security features

Dependabot alerts stay on and Dependabot security updates stay off, because Renovate reads the alerts and opens the security pull requests itself, outside its schedule and the preset's release-age floor. One updater then gives security bumps the preset's commit types, labels, and automerge, and a repository needs no `dependabot.yml`. Private vulnerability reporting is the channel the default `SECURITY.md` names, and secret scanning with push protection keeps credentials out of the history.

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

| Label              | Color    | Description                                 |
| ------------------ | -------- | ------------------------------------------- |
| `bug`              | `d73a4a` | Something isn't working                     |
| `enhancement`      | `a2eeef` | New feature or request                      |
| `documentation`    | `0075ca` | Improvements or additions to documentation  |
| `good first issue` | `7057ff` | Good for newcomers                          |
| `help wanted`      | `008672` | Extra attention is needed                   |
| `dependencies`     | `0366d6` | Pull requests that update a dependency file |

Labels do not mirror commit types, since a pull request's title already carries its type and the changelog groups by it. `bug`, `enhancement`, and `documentation` sort issues, which have no commit type, and the pull requests that resolve them. The other GitHub defaults go, since the close reasons "duplicate" and "not planned" replace `duplicate`, `invalid`, and `wontfix`, and an issue asking a question needs no label. A new repository already has the first five labels, so applying the set takes:

```bash
for label in duplicate invalid question wontfix; do
  gh label delete "$label" --yes
done
gh label create dependencies \
  --color 0366d6 \
  --description 'Pull requests that update a dependency file' \
  --force
```

Milestones stay unused, since a release ships when it is ready and the range since the last tag shows what it holds.

## Inherit the community files

The public [`hakula139/.github`](https://github.com/hakula139/.github) repository supplies every repository's default pull request template, issue forms, and `SECURITY.md`, and a repository's own file overrides each one. Any file in a repository's own `.github/ISSUE_TEMPLATE/` replaces the whole default issue folder.
