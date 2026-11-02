# AGENTS.md: devkit

devkit holds the development tooling that Hakula's repositories share by reference.

## Read before you edit

| When the change touches                  | Read                   |
| ---------------------------------------- | ---------------------- |
| The pre-commit baseline or the dev shell | [Hooks](docs/hooks.md) |

## Layout

```text
.
├── .cspell/       # Project spelling dictionary
├── .github/       # actionlint and Dependabot configs, and the CI workflows
├── actions/       # setup-nix and ci-result composite actions
├── docs/          # Hooks
├── nix/           # Hook baseline, library, and tests
├── flake.nix      # The exported `lib`, checks, and dev shell
└── README.md      # What each piece is and how a repository adopts it
```

## Rules for every change

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run `nix develop -c true` once to install them. Never bypass the hooks with `--no-verify` or `PRE_COMMIT_ALLOW_NO_CONFIG`. When a hook, test, or CI job fails, fix its cause.
- Wrap code and comments at 100 columns, counting the indent, end section banners at column 100, and keep a single-line string literal whole at any length.
- Update whatever the change makes stale: the README's adoption snippets and the docs page that owns the changed contract.
- Workflows use `$/` self-repository references for both actions and job-level reusable workflow calls. `$/` always resolves against the repository of the file it appears in, so a caller at any ref runs that ref's actions and workflows. Do not replace it with `./` or a hard-coded tag.
- Link only public material in issues, pull requests, and their comments, and never reference local working notes, private paths, or private repositories.

## Verification

```bash
nix flake check --all-systems
```

## Documentation maintenance

Give each rule one home and link to it from other pages. Add a constraint to this file or `docs/` only if it is invisible, is destructive, or has already cost someone a debugging session, and leave out whatever a model can read from the flake, an action, or the tests.

- `README.md` is for a repository deciding whether and how to adopt a piece.
- `AGENTS.md` is for whoever changes the code, and `docs/` serves both contributors and adopters.
- Keep the layout tree accurate at its current depth.

## Code review

Review the change and its affected callers against the docs, checking in particular that an action's inputs, a workflow's inputs and secrets, and a `lib` function's arguments keep the contract stated in the README and docs.
