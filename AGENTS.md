# AGENTS.md: devkit

## Read before you edit

| When the change touches                                      | Read                                   |
| ------------------------------------------------------------ | -------------------------------------- |
| `mkLib`, `lib.systems`, or `lib.eachSystem`                  | [Nix flake](docs/flake.md)             |
| The pre-commit baseline or dev shell                         | [Hooks](docs/hooks.md)                 |
| Nushell application builders, `dk.nushell`, or skill helpers | [Nushell tooling](docs/nushell.md)     |
| `nu-test`, `nu-check`, or `nuTests`                          | [Nushell test runner](docs/nu-test.md) |
| Nix or language CI, `ci-result`, or Workers deployment       | [CI workflow and gate](docs/ci.md)     |
| An action, a reusable workflow, or `cliff.toml`              | [Releasing](docs/releasing.md)         |
| A devkit release or versioning decision                      | [Releasing devkit](RELEASING.md)       |
| The Renovate preset                                          | [Renovate preset](docs/renovate.md)    |
| Repository settings, rulesets, or labels                     | [GitHub conventions](docs/github.md)   |

## Conventions

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run `nix develop -c true` once to install them. Never bypass the hooks with `--no-verify` or `PREK_ALLOW_NO_CONFIG`.
- Wrap code and comments at 100 columns, counting the indent, and end section banners at column 100.
- Every consumer inherits devkit's choices, so redesign each construct the change touches to its ecosystem's simple, conventional idiom, consistent with the rest of devkit. Reach for the upstream tool's own option first and, in Nix, a nixpkgs `lib` primitive next. Keep a non-standard choice only for a concrete reason, recorded in a comment at the choice or in the docs page that owns its contract.
- Update affected adoption snippets and the guide that owns the changed contract. Preserve setup steps, design rationale, and contributor rules in the guide or a skill it names. Link to source for implementation details.
- Use lists for parallel requirements or ordered steps and tables for comparisons when they make a decision easier to follow.
- Use `$/` for self-references to GitHub Actions and job-level reusable workflows. GitHub resolves it against the repository and ref of the file containing the reference, so a consumer runs the devkit revision it selected.
- Link only public material in issues, pull requests, and their comments, and never reference local working notes, private paths, or private repositories.

## Verification

```bash
nix flake check --all-systems
nix develop -c run-hooks
```

## Code review

Review the change and its affected callers against the docs, checking in particular that it keeps the contract in [Choose the version](RELEASING.md#choose-the-version).
