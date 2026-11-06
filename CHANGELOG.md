# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0-rc.1] - 2026-11-06

### Added

- The `devkit.lib` flake output with `systems`, `eachSystem`, `mkLib`, and the skill helpers.
- `dk.preCommit`, which generates the shared pre-commit hook baseline and the dev shell that installs it.
- The Nushell tooling: the `nu-test` parallel runner, `nu-check`, `nuTests`, and `mkNuApplication`.
- The `setup-nix`, `ci-result`, `tagged-ci`, and `publish-release` composite actions.
- The `nix.yml`, `release.yml`, and `nix-cache.yml` reusable workflows.
- The Renovate preset in `default.json`.

[Unreleased]: https://github.com/hakula139/devkit/compare/v1.0.0-rc.1...HEAD
[1.0.0-rc.1]: https://github.com/hakula139/devkit/releases/tag/v1.0.0-rc.1
