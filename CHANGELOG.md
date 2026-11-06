# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0-rc.2] - 2026-11-06

### Changed

- `.editorconfig` sets the shell formatting properties for `*.zsh` as well as `*.sh`.
- devkit exposes `packages.default` as `checks.package`, and the README tells a consumer to do the same, so `nix flake check` builds the package.
- The README states that a flake ref pins the major tag.

### Fixed

- `.markdownlint-cli2.jsonc` disables `first-line-heading`, so a PR template that starts with `## Summary` passes the baseline hook.
- The Renovate preset's custom manager matches a flake ref only when it pins a bare major tag, leaving a full-version ref such as `v1.0.0-rc.1` unchanged instead of rewriting its major prefix.

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
