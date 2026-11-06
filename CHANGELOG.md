# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0-rc.3 - 2026-11-06

### Breaking changes

- The flake no longer exports `packages.default`, the bundle of `nu-check` and `nu-test`. Build both from your own package set with `devkit.lib.mkLib pkgs`. No known consumer uses the output.

### Added

- A `dprint` baseline hook formats Markdown before `markdownlint-cli2` lints it. The hook passes its own config, so a repository's `dprint.json` doesn't apply to Markdown. A repository's lock-maintenance PR fails until it adopts dprint's formatting, which `nix develop -c prek run --all-files` applies from a checkout outside a gitignored path such as `.claude/worktrees/`.
- A `doctoc` baseline hook regenerates a Markdown table of contents, three heading levels deep and without a title line, between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers, and leaves a file without them untouched. A repository that defines its own `doctoc` hook can drop it, and a TOC generated with other flags is regenerated on the next run. Keep reference-style links out of headings, since doctoc builds their anchors from the raw source.
- `cliff.toml`, a shared git-cliff config that drafts a release's `CHANGELOG.md` section from the squash-merged PR titles, which "Cut a release" in `docs/releasing.md` runs with `--config-url`. The draft keeps only `feat`, `fix`, `perf`, and `!` titles, so give a PR that changes what consumers see one of those types. Version headings read `## 1.2.3 - <date>` without brackets. The config's `header` must match the top of `CHANGELOG.md` exactly, since `--prepend` replaces only an identical header, and devkit changes it or moves the file only in a new major release. Delete any trailing compare-link definitions from `CHANGELOG.md`, which would otherwise leak into the oldest section's release notes. The `v1` URL serves the file once `v1.0.0` moves the `v1` tag, so until then fetch it from the `v1.0.0-rc.3` tag.
- `docs/github.md` states the defaults a repository starts from, namely the branch ruleset, immutable releases, the repository and security settings, and the labels, with the `gh` commands that apply them. The label commands delete every label outside the kept set, which strips it from every issue and PR and cannot be undone.

### Changed

- `.markdownlint-cli2.jsonc` sets `code-fence-style`, `emphasis-style`, `heading-style`, `strong-style`, and `ul-style` to match dprint's output. Copy all five into a consumer's file, since without an explicit `emphasis-style` the two hooks rewrite each other's output on any file with intraword emphasis.
- `.markdownlint-cli2.jsonc` no longer disables `first-line-heading`, since the shared PR template now lives in `hakula139/.github`. A repository that uses that template drops the setting together with its own template copy, while one that keeps a template starting at `##` keeps it.
- The baseline's `actionlint` is the unpatched nixpkgs package, which the binary cache supplies, and a consumer that needs the `queue` key adds `'unexpected key "queue" for "concurrency" section'` to its `.github/actionlint.yaml` ignores.
- A releasing repository no longer needs a `nix-cache.yml` caller, because a deleted pin is restored locally. An existing caller keeps working, since devkit's `nix-cache.yml` still takes `workflow_call`.
- `release.yml`'s cache job id is `nix-cache`, so a release run's checks read `release / nix-cache / Pin (<system>)` in place of `release / nix / Pin (<system>)`.

### Fixed

- `nu-test` reports why a test file failed to load when the file prints to stdout or exits while it loads, where it used to show only the stray output or crash with `Can't convert to record` and leave a scratch directory behind. Move any such output or `exit` out of the file's top level.
- `nu-test` installs a test file's stubs when the file's directory name holds glob characters such as `[1]`.
- `publish-release` passes the release notes to `gh` without writing them to a file, so an `assets` glob that matches `*.md` no longer attaches a `release-notes.md` to the release.

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
