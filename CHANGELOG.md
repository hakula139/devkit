# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The baseline's `actionlint` is the unpatched nixpkgs package, which the binary cache supplies, and a consumer that needs the `queue` key adds `'unexpected key "queue" for "concurrency" section'` to its `.github/actionlint.yaml` ignores.

## [1.0.0-rc.2] - 2026-11-06

### Changed

- The README tells a consumer to expose the package as `checks.<system>.package`, so `nix.yml`'s `nix flake check` builds it.

### Fixed

- `.markdownlint-cli2.jsonc` is a starting point that disables `first-line-heading`, so a PR template that starts with `## Summary` passes the baseline hook. Copy the setting into a consumer's file.
- `.editorconfig` is a starting point whose shell section now covers `*.zsh` as well as `*.sh`. Copy the section into a consumer's file.
- The Renovate preset's custom manager matches only a flake reference that pins the major tag, such as `github:hakula139/devkit/v1`, and now moves `v1` to `v2` correctly. It leaves a full-version ref such as `v1.0.0-rc.1` unchanged. In rc.1, the same manager broke a major update by rewriting the owner in `hakula139` to `hakula239`.
- The `nu-test` runner rejects a test name that holds characters outside letters, digits, spaces, and `,.:-`, so a `;` in a name can no longer inject a command and an apostrophe no longer breaks the run. Rename any test whose name falls outside that set.

## [1.0.0-rc.1] - 2026-11-06

### Added

- The `devkit.lib` flake output with `systems`, `eachSystem`, `mkLib`, `skillDirectoriesOption`, `skillLinks`, and `skillSource`.
- `devkit.lib.mkLib pkgs`, which binds the package set for the tools below, all named without a `dk.` prefix.
- `preCommit`, which generates the shared pre-commit hook baseline and the dev shell that installs it.
- The Nushell tooling: `nushell`, the `nu-test` parallel runner, `nu-check`, `nuTests`, and `mkNuApplication`.
- `nodeTool` and `uvTool`, which wrap a command to run through pnpm or `uv run --locked`.
- The `setup-nix`, `ci-result`, `tagged-ci`, and `publish-release` composite actions.
- The `nix.yml`, `release.yml`, and `nix-cache.yml` reusable workflows.
- The Renovate preset in `default.json`.

[Unreleased]: https://github.com/hakula139/devkit/compare/v1.0.0-rc.2...HEAD
[1.0.0-rc.2]: https://github.com/hakula139/devkit/compare/v1.0.0-rc.1...v1.0.0-rc.2
[1.0.0-rc.1]: https://github.com/hakula139/devkit/releases/tag/v1.0.0-rc.1
