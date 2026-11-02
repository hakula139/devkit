# AGENTS.md: devkit

`devkit` holds the development tooling that Hakula's repositories share by reference: composite
actions, a reusable Nix workflow, the pre-commit baseline, the Nushell test tooling, and the
Renovate preset.

## Read before you edit

| When the change touches                   | Read                                   |
| ----------------------------------------- | -------------------------------------- |
| A composite action or a reusable workflow | [Releasing](docs/releasing.md)         |
| The pre-commit baseline or the dev shell  | [Hooks](docs/hooks.md)                 |
| `nu-test`, `nu-check`, or `lib.nuTests`   | [Nushell test runner](docs/nu-test.md) |
| A release or a versioning decision        | [Releasing](docs/releasing.md)         |

## Rules for every change

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run
  `nix develop -c true` once to install them. Never bypass the hooks with `--no-verify` or
  `PRE_COMMIT_ALLOW_NO_CONFIG`. When a hook, test, or CI job fails, fix its cause.
- Wrap code and comments at 100 columns, counting the indent, and end section banners at column
  100.
- Add new words to `.cspell/words.txt` in alphabetical order.
- Update whatever the change makes stale: the README's adoption snippets, the docs page that owns
  the changed contract, and the consumers named in the adoption table when an interface moves.
- Issues, pull requests, and their comments link only public material. Never reference local
  working notes, private paths, or private repositories.

## Verification

```bash
nix flake check                                  # Hooks, Nushell tests, and the fixture application
nix build --no-link --print-build-logs           # The exported packages
nix develop -c prek run --all-files              # Every hook, over every tracked file
actionlint .github/workflows/*.yml               # Workflow syntax and expressions
```

## Documentation maintenance

Each rule has one home, which other pages link to. Add to this file or `docs/` only a constraint
that is invisible, destructive, or already cost someone a debugging session, and leave out
whatever a model can read off the flake, an action, or the tests.

- `README.md` is for a repository deciding whether and how to adopt a piece.
- `AGENTS.md` and `docs/` are for whoever changes the code.
- Keep the layout tree accurate at its current depth.

## Code review

Review the change and its affected consumers against the docs, and check in particular that an
action's inputs, a workflow's inputs and secrets, and a `lib` function's arguments keep the
contract the plan and the README state.
