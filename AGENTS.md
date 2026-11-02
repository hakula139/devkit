# AGENTS.md: devkit

`devkit` holds the development tooling that Hakula's repositories share by reference: composite actions, reusable workflows, the pre-commit baseline, the Nushell test tooling, and the Renovate preset.

## Read before you edit

| When the change touches                   | Read                   |
| ----------------------------------------- | ---------------------- |
| A composite action or a reusable workflow | [Hooks](docs/hooks.md) |
| The pre-commit baseline or the dev shell  | [Hooks](docs/hooks.md) |

## Layout

```text
.
├── .cspell/       # Project spelling dictionary
├── .github/       # Actionlint config, CI, and the Nix workflow
├── actions/       # setup-nix and ci-result composite actions
├── docs/          # Hooks
├── nix/           # Hook baseline, dev shell, and Node hook
├── flake.nix      # The exported `lib`, packages, checks, and dev shell
└── README.md      # What each piece is and how a repository adopts it
```

## Rules for every change

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run `nix develop -c true` once to install them. Never bypass the hooks with `--no-verify` or `PRE_COMMIT_ALLOW_NO_CONFIG`. When a hook, test, or CI job fails, fix its cause.
- Wrap code and comments at 100 columns, counting the indent, end section banners at column 100, and keep a single-line string literal whole at any length.
- Add new words to `.cspell/words.txt` in alphabetical order.
- Update whatever the change makes stale: the README's adoption snippets and the docs page that owns the changed contract.
- Workflows use `$/` self-repository references for both actions and job-level reusable workflow calls. `$/` always resolves against the repository of the file it appears in, so a caller at `@v1` runs that release's actions and workflows. Do not replace it with `./` or a hard-coded tag.
- Issues, pull requests, and their comments link only public material. Never reference local working notes, private paths, or private repositories.

## Verification

```bash
nix flake check
nix build
nix develop -c prek run --all-files
actionlint .github/workflows/*.yml
```

`actionlint` 1.7.12 rejects the `$/` syntax, and `.github/actionlint.yaml` ignores only that message, so a real missing `@ref` still fails. Drop the config when actionlint learns the syntax.

## Documentation maintenance

Each rule has one home, which other pages link to. Add to this file or `docs/` only a constraint that is invisible, destructive, or already cost someone a debugging session, and leave out whatever a model can read off the flake, an action, or the tests.

- `README.md` is for a repository deciding whether and how to adopt a piece.
- `AGENTS.md` and `docs/` are for whoever changes the code.
- Keep the layout tree accurate at its current depth.

## Code review

Review the change and its affected consumers against the docs, and check in particular that an action's inputs, a workflow's inputs and secrets, and a `lib` function's arguments keep the contract the README and docs state.
