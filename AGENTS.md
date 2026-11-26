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

- Install the pre-commit hooks once in each new checkout or worktree with `nix develop -c true` and run them on every commit. Never bypass them with `--no-verify` or `PREK_ALLOW_NO_CONFIG`.
- Wrap code and comments at 100 columns, counting the indent, and end section banners at column 100.
- Consumers inherit devkit's choices, so bring each construct you touch into line with the conventions of its ecosystem and the rest of devkit. Start with the upstream tool's own options, then consider a nixpkgs `lib` primitive when working in Nix. Keep a non-standard choice only for a concrete reason and record that reason in a comment beside it or in the guide that owns its contract.
- When a contract changes, update its guide and the affected adoption snippets. Keep setup steps, design rationale, and contributor rules in the guide or a skill it names, and link to the source for implementation details.
- Use lists for parallel requirements or ordered steps and tables for comparisons when they make a decision easier to follow.
- Use `$/` for self-references to GitHub Actions and job-level reusable workflows. GitHub resolves these references against the containing file's repository and ref, so each consumer runs the devkit revision it selected.
- Link only to public material in issues, pull requests, and their comments, and never reference local working notes, private paths, or private repositories.

## Verification

```bash
nix flake check --all-systems
nix develop -c run-hooks
```

## Code review

Review the change and its affected callers against the documented contracts, paying particular attention to the versioning rules in [Choose the version](RELEASING.md#choose-the-version).
