# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-08

### Breaking changes

- Composite actions now live under `.github/actions/`. Update `hakula139/devkit/actions/<name>@<ref>` to `hakula139/devkit/.github/actions/<name>@v1` for `setup-nix`, `ci-result`, `tagged-ci`, and `publish-release`. Reusable workflow paths stay under `.github/workflows/`. ([#24](https://github.com/hakula139/devkit/pull/24))
- Consumers explicitly enable language and tool hooks with `enable = true`, including hooks configured through `package` or `devHooks`. Only `check-added-large-files`, `check-merge-conflicts`, `end-of-file-fixer`, and `trim-trailing-whitespace` are enabled by default. ([#20](https://github.com/hakula139/devkit/pull/20))
- The flake no longer exports `packages.default`. Build `nu-check` and `nu-test` through `devkit.lib.mkLib pkgs`. ([#9](https://github.com/hakula139/devkit/pull/9))

### Added

- The `devkit.lib` output provides `systems`, `eachSystem`, `mkLib`, `skillDirectoriesOption`, `skillLinks`, and `skillSource` for shared Nix tooling and skill installation.
- `preCommit` provides a shared check and dev shell from an explicit `src`, supporting flake and classic `shell.nix` consumers. The shell installs configured prek stages when entered from a Git checkout, preserves custom hook paths, and retains hook tools across garbage collection. ([#20](https://github.com/hakula139/devkit/pull/20))
- _(hooks)_ Optional dprint and doctoc hooks format Markdown and maintain marked tables of contents through `###` headings. dprint uses the shared Markdown configuration. ([#13](https://github.com/hakula139/devkit/pull/13), [#16](https://github.com/hakula139/devkit/pull/16))
- Shared formatter configuration uses the source root's `.prettierrc.json` and `.taplo.toml` when present, with tool defaults otherwise. The actionlint package recognizes `concurrency.queue` and `client-id` in `actions/create-github-app-token@v3`. ([#20](https://github.com/hakula139/devkit/pull/20))
- _(nu)_ Nushell tooling includes `nu-check`, the parallel `nu-test` runner, `nuTests`, and `mkNuApplication` with skill packaging. It uses the consumer's Nushell at version 0.116 or later, with devkit's unstable input supplying older package sets.
- _(nu)_ `nu-test` validates test names, reports files that print or exit during discovery as load failures, and installs stubs from directories containing glob characters. Test names may contain letters, digits, spaces, and `,.:-`. ([#6](https://github.com/hakula139/devkit/pull/6), [#10](https://github.com/hakula139/devkit/pull/10), [#14](https://github.com/hakula139/devkit/pull/14))
- `nodeTool` and `uvTool` run repository-pinned commands through `pnpm exec` and `uv run --locked`.
- The four composite actions and the `nix.yml`, `release.yml`, and `nix-cache.yml` workflows share Nix setup, CI gates, package cache pins, and changelog-based releases. Gates retain each job's latest result across reruns, and release notes are passed directly to `gh` so asset globs do not attach a generated notes file. ([#10](https://github.com/hakula139/devkit/pull/10), [#20](https://github.com/hakula139/devkit/pull/20))
- `cliff.toml` drafts release sections from `feat`, `fix`, `perf`, and breaking conventional titles. `scripts/changelog.nu` prepends drafts using local or shared configuration. The release guide covers curated notes, release PRs, publication, and recovery. ([#11](https://github.com/hakula139/devkit/pull/11), [#19](https://github.com/hakula139/devkit/pull/19))
- The shared Renovate preset groups dependency updates and automerges lock maintenance. Its flake manager upgrades major-only devkit references such as `/v1` to `/v2`. ([#6](https://github.com/hakula139/devkit/pull/6))
- _(github)_ `scripts/github.nu` applies repository settings, branch rulesets, shared labels, and release notes. Configuration lives under `.github/settings/`, custom labels are preserved, and repositories can add `area: <component>` labels or supply their own ruleset. ([#12](https://github.com/hakula139/devkit/pull/12), [#17](https://github.com/hakula139/devkit/pull/17), [#21](https://github.com/hakula139/devkit/pull/21), [#26](https://github.com/hakula139/devkit/pull/26))
- Starter EditorConfig, Markdownlint, and Prettier configurations include zsh formatting and consistent property quoting. ([#6](https://github.com/hakula139/devkit/pull/6), [#12](https://github.com/hakula139/devkit/pull/12), [#25](https://github.com/hakula139/devkit/pull/25))

### Changed

- Adoption guides now live under `docs/`, with a short README index linking flake, hooks, Nushell, CI, release, Renovate, and GitHub guidance. ([#23](https://github.com/hakula139/devkit/pull/23))

[1.0.0]: https://github.com/hakula139/devkit/releases/tag/v1.0.0

## [1.0.0-rc.3] - 2026-11-06

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

[1.0.0-rc.3]: https://github.com/hakula139/devkit/compare/v1.0.0-rc.2...v1.0.0-rc.3

## [1.0.0-rc.2] - 2026-11-06

### Changed

- The README tells a consumer to expose the package as `checks.<system>.package`, so `nix.yml`'s `nix flake check` builds it.

### Fixed

- `.markdownlint-cli2.jsonc` is a starting point that disables `first-line-heading`, so a PR template that starts with `## Summary` passes the baseline hook. Copy the setting into a consumer's file.
- `.editorconfig` is a starting point whose shell section now covers `*.zsh` as well as `*.sh`. Copy the section into a consumer's file.
- The Renovate preset's custom manager matches only a flake reference that pins the major tag, such as `github:hakula139/devkit/v1`, and now moves `v1` to `v2` correctly. It leaves a full-version ref such as `v1.0.0-rc.1` unchanged. In rc.1, the same manager broke a major update by rewriting the owner in `hakula139` to `hakula239`.
- The `nu-test` runner rejects a test name that holds characters outside letters, digits, spaces, and `,.:-`, so a `;` in a name can no longer inject a command and an apostrophe no longer breaks the run. Rename any test whose name falls outside that set.

[1.0.0-rc.2]: https://github.com/hakula139/devkit/compare/v1.0.0-rc.1...v1.0.0-rc.2

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

[1.0.0-rc.1]: https://github.com/hakula139/devkit/releases/tag/v1.0.0-rc.1
