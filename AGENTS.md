# AGENTS.md: devkit

devkit holds the development tooling that Hakula's repositories share by reference.

## Read before you edit

| When the change touches                                             | Read                                   |
| ------------------------------------------------------------------- | -------------------------------------- |
| The pre-commit baseline or the dev shell                            | [Hooks](docs/hooks.md)                 |
| `nu-test`, `nu-check`, or `nuTests`                                 | [Nushell test runner](docs/nu-test.md) |
| An action, a reusable workflow, a release, or a versioning decision | [Releasing](docs/releasing.md)         |

## Layout

```text
.
├── .cspell/       # Project spelling dictionary
├── .github/       # actionlint and Dependabot configs, and the CI and release workflows
├── actions/       # setup-nix, ci-result, tagged-ci, and publish-release composite actions
├── docs/          # Hooks, the Nushell test runner, and releasing
├── nix/           # Hook baseline, library, Nushell tooling, and tests
├── CHANGELOG.md   # Release notes, one section per tag
├── flake.nix      # The exported `lib`, package, checks, and dev shell
└── README.md      # What each piece is and how a repository adopts it
```

## Rules for every change

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run `nix develop -c true` once to install them. Never bypass the hooks with `--no-verify` or `PRE_COMMIT_ALLOW_NO_CONFIG`. When a hook, test, or CI job fails, fix its cause.
- Wrap code and comments at 100 columns, counting the indent, end section banners at column 100, and keep a single-line string literal whole at any length.
- Update whatever the change makes stale: the README's adoption snippets and the docs page that owns the changed contract.
- Workflows use `$/` self-repository references for both actions and job-level reusable workflow calls. `$/` resolves against the repository of the file it appears in, at the commit that is running, so a caller at any ref runs that ref's actions and workflows. Do not replace it with `./` or a hard-coded tag.
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

Review the change and its affected callers against the docs, checking in particular that it keeps the contract [Release devkit](docs/releasing.md#release-devkit) lists.
