# AGENTS.md: devkit

devkit holds the development tooling that Hakula's repositories share by reference.

## Read before you edit

| When the change touches                                                                   | Read                                   |
| ----------------------------------------------------------------------------------------- | -------------------------------------- |
| The pre-commit baseline or the dev shell                                                  | [Hooks](docs/hooks.md)                 |
| `nu-test`, `nu-check`, or `nuTests`                                                       | [Nushell test runner](docs/nu-test.md) |
| An action, a reusable workflow, the git-cliff config, a release, or a versioning decision | [Releasing](docs/releasing.md)         |
| The Renovate preset                                                                       | [Renovate preset](docs/renovate.md)    |
| A repository setting, the branch ruleset, or a label                                      | [GitHub conventions](docs/github.md)   |

## Layout

```text
.
├── .cspell/                    # Project spelling dictionary
├── .github/                    # Composite actions, workflows, and GitHub configuration
├── docs/                       # Adoption guides and shared tooling reference
├── nix/                        # Nix library, hooks, builders, and private package overrides
├── scripts/                    # Repository administration helpers
├── src/                        # Exported Nushell executable sources
├── .markdownlint-cli2.jsonc    # The shared markdownlint-cli2 rules the hook applies
├── .prettierrc.json            # The shared Prettier style, whose `overrides` match basenames only
├── .taplo.toml                 # The shared Taplo formatting the hook applies
├── CHANGELOG.md                # Release notes, one section per tag
├── cliff.toml                  # The shared git-cliff config that drafts each release section
├── default.json                # The Renovate preset consumers extend
├── flake.nix                   # The exported `lib`, checks, and dev shell
└── README.md                   # Project overview and documentation index
```

## Rules for every change

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run `nix develop -c true` once to install them. Never bypass the hooks with `--no-verify` or `PRE_COMMIT_ALLOW_NO_CONFIG`, and fix the cause whenever a hook, test, or CI job fails.
- Wrap code and comments at 100 columns, counting the indent, end section banners at column 100, and keep a single-line string literal whole at any length.
- Update whatever the change makes stale, including adoption snippets and the docs page that owns the changed contract.
- Workflows use `$/` self-repository references for both actions and job-level reusable workflow calls. `$/` resolves against the repository of the file it appears in at the running commit, so a caller at any ref runs that ref's actions and workflows. Do not replace it with `./` or a hard-coded tag.
- Link only public material in issues, pull requests, and their comments, and never reference local working notes, private paths, or private repositories.

## Verification

```bash
nix flake check --all-systems
```

## Documentation maintenance

Give each rule one home and link to it from other pages. Add a constraint to this file or `docs/` only if it is invisible, is destructive, or has already cost someone a debugging session, and leave out whatever a model can read from the flake, an action, or the tests.

- `README.md` is for a repository deciding whether and how to adopt a piece.
- `AGENTS.md` is for whoever changes the code.
- `docs/` serves both contributors and adopters.

## Code review

Review the change and its affected callers against the docs, checking in particular that it keeps the contract in [Release devkit](docs/releasing.md#release-devkit).
