# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0-rc.3 - 2026-11-06

### Breaking changes

- The flake no longer exports `packages.default`, the bundle of `nu-check` and `nu-test`. Build both from your own package set with `devkit.lib.mkLib pkgs`. No known consumer uses the output.

### Added

- A `dprint` baseline hook formats Markdown before `markdownlint-cli2` lints it, using its own config, so a repository's `dprint.json` doesn't apply to Markdown. A repository's lock-maintenance PR fails until it adopts dprint's formatting, which `nix develop -c prek run --all-files` applies. Keep `emphasis-style: underscore` in `.markdownlint-cli2.jsonc`, since under the `consistent` default the two hooks rewrite each other's output on any file with intraword emphasis.
- A `doctoc` baseline hook fills a table of contents through `###` headings, without a title line, between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers, and leaves a file without them untouched. A repository can drop its own `doctoc` hook, and one whose TOC was built with other flags fails its lock-maintenance PR until the hook regenerates it. Keep reference-style links out of headings, since doctoc builds their anchors from the raw source.
- `cliff.toml`, a shared git-cliff config that drafts a release's `CHANGELOG.md` section from `feat`, `fix`, `perf`, and `!` PR titles under unbracketed `## 1.2.3 - <date>` headings, as "Cut a release" in `docs/releasing.md` shows. Start `CHANGELOG.md` with the config's `header` exactly, since `--prepend` replaces only an identical header, and delete any trailing compare-link definitions. Until `v1.0.0` creates the `v1` tag, fetch the config from the `v1.0.0-rc.3` tag.
- `docs/github.md` gives the default branch ruleset, release immutability, repository and security settings, and labels, with the `gh` commands that apply them.

### Fixed

- `nu-test` explains the `(load)` failure of a test file that prints to stdout or exits while it loads, where it used to show only the stray output or crash with `Can't convert to record` and leave a scratch directory behind.
- `nu-test` installs a test file's stubs when the file's directory name holds glob characters such as `[1]`.
- `publish-release` passes the release notes to `gh` without writing them to a file, so an `assets` glob that matches `*.md` no longer attaches a `release-notes.md` to the release.

### Changed

- `.markdownlint-cli2.jsonc` no longer disables `first-line-heading`. A repository that switches to the shared PR template in `hakula139/.github` drops the setting along with its own template copy.
- The baseline's `actionlint` rejects `queue` in a `concurrency` section. A repository that uses it adds `'unexpected key "queue" for "concurrency" section'` to its `.github/actionlint.yaml` ignores.
- A releasing repository can delete its `nix-cache.yml` caller, since `docs/releasing.md` now restores a deleted pin locally. An existing caller keeps working.

## 1.0.0-rc.2 - 2026-11-06

### Changed

- The README tells a consumer to expose the package as `checks.<system>.package`, so `nix.yml`'s `nix flake check` builds it.

### Fixed

- `.markdownlint-cli2.jsonc` is a starting point that disables `first-line-heading`, so a PR template that starts with `## Summary` passes the baseline hook. Copy the setting into a consumer's file.
- `.editorconfig` is a starting point whose shell section now covers `*.zsh` as well as `*.sh`. Copy the section into a consumer's file.
- The Renovate preset's custom manager matches only a flake reference that pins the major tag, such as `github:hakula139/devkit/v1`, and now moves `v1` to `v2` correctly. It leaves a full-version ref such as `v1.0.0-rc.1` unchanged. In rc.1, the same manager broke a major update by rewriting the owner in `hakula139` to `hakula239`.
- The `nu-test` runner rejects a test name that holds characters outside letters, digits, spaces, and `,.:-`, so a `;` in a name can no longer inject a command and an apostrophe no longer breaks the run. Rename any test whose name falls outside that set.

## 1.0.0-rc.1 - 2026-11-06

### Added

- The `devkit.lib` flake output with `systems`, `eachSystem`, `mkLib`, `skillDirectoriesOption`, `skillLinks`, and `skillSource`.
- `devkit.lib.mkLib pkgs`, which binds the package set for the tools below, all named without a `dk.` prefix.
- `preCommit`, which generates the shared pre-commit hook baseline and the dev shell that installs it.
- The Nushell tooling: `nushell`, the `nu-test` parallel runner, `nu-check`, `nuTests`, and `mkNuApplication`.
- `nodeTool` and `uvTool`, which wrap a command to run through pnpm or `uv run --locked`.
- The `setup-nix`, `ci-result`, `tagged-ci`, and `publish-release` composite actions.
- The `nix.yml`, `release.yml`, and `nix-cache.yml` reusable workflows.
- The Renovate preset in `default.json`.
