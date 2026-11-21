# AGENTS.md: devkit

## Read before you edit

Read the [guide for the area you are changing](README.md#documentation).

## Conventions

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run `nix develop -c true` once to install them. Never bypass the hooks with `--no-verify` or `PREK_ALLOW_NO_CONFIG`.
- Wrap code and comments at 100 columns, counting the indent, and end section banners at column 100.
- Every consumer inherits devkit's choices, so redesign each construct the change touches to its ecosystem's simple, conventional idiom, consistent with the rest of devkit. Reach for the upstream tool's own option first and, in Nix, a nixpkgs `lib` primitive next. Keep a non-standard choice only for a concrete reason, recorded in a comment at the choice or in the docs page that owns its contract.
- Update affected adoption snippets and the guide that owns the changed contract. Document setup, design rationale, and maintenance conventions. Link to the source for behavior readers can infer there.
- Use `$/` for actions and reusable workflow calls within devkit so each consumer runs them at the ref it selected.
- Link only public material in issues, pull requests, and their comments, and never reference local working notes, private paths, or private repositories.

## Verification

```bash
nix flake check --all-systems
nix develop -c run-hooks
```

## Code review

Review the change and its affected callers against the docs, checking in particular that it keeps the contract in [Choose the version](RELEASING.md#choose-the-version).
