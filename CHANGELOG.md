# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed

- _(hooks)_ Prettier's baseline `files` covers CSS, so a repository that enables the hook also formats `.css` files. ([#78](https://github.com/hakula139/devkit/pull/78))

### Fixed

- _(hooks)_ Entering the dev shell replaces an existing Git hook with prek's shim instead of leaving prek in migration mode, so commits and pushes no longer fail in a clone whose hooks another tool installed. ([#77](https://github.com/hakula139/devkit/pull/77))

## [3.1.0] - 2026-11-10

### Added

- _(ci)_ The reusable `python.yml`, `node.yml`, and `rust.yml` workflows run a repository's tests with Codecov coverage, plus doc tests and an optional MSRV check in `rust.yml`, and are called like `nix.yml`. Codecov authenticates through OIDC, so the calling job grants `id-token: write`, even with `coverage: false`, and no `CODECOV_TOKEN` secret is needed. `docs/ci.md` sets the conventions for a repository's own CI jobs, including job ids and names, tool flags kept in the tool's configuration, and which checks belong in `nix flake check`. ([#61](https://github.com/hakula139/devkit/pull/61), [#73](https://github.com/hakula139/devkit/pull/73))
- _(nushell)_ `dk.writeNuApplication { name, text, runtimeInputs, makeWrapperArgs, meta }` builds a single-file Nushell command, shaped like `writeShellApplication` and guarded like `mkNuApplication`. ([#63](https://github.com/hakula139/devkit/pull/63))
- _(github)_ `settings --private` and `ruleset --private` skip what GitHub lacks for a private repository, namely private vulnerability reporting, secret scanning, and the ruleset, printing a note for each. ([#55](https://github.com/hakula139/devkit/pull/55))
- _(release)_ When `.claude-plugin/plugin.json` sets a `version`, `release.yml` fails unless it matches the package version. ([#70](https://github.com/hakula139/devkit/pull/70))
- _(renovate)_ The devkit major update also bumps the refs in every Markdown file except `CHANGELOG.md`, and in both Markdown and `flake.nix` it matches `uses: hakula139/devkit/...@vN`, `github>hakula139/devkit#vN`, and `github.com/hakula139/devkit/blob/vN` or `tree/vN` besides `github:hakula139/devkit/vN`. ([#68](https://github.com/hakula139/devkit/pull/68))

### Changed

- _(hooks)_ The baseline enables `actionlint`, `check-yaml`, `cspell`, `deadnix`, `dprint`, `editorconfig-checker`, `markdownlint-cli2`, `nixfmt`, `sort-file-contents`, and `statix` by default, so a repository that left them off gets their findings after updating. `cspell` needs a `cspell.json` with a project dictionary, and `hooks.<name>.enable = false` turns any of them off. ([#54](https://github.com/hakula139/devkit/pull/54))
- _(hooks)_ `mkLib` takes Ruff and uv from the consumer's nixpkgs only at 0.17 and 0.13 or later, and otherwise from devkit's `nixpkgs-unstable`, which replaces nixos-26.05's Ruff 0.15.14 and uv 0.11.21 with 0.17.3 and 0.13.5. The newer Ruff may reformat code or report new findings. `ruff-format.package` defaults to `hooks.ruff.package`, so `hooks.ruff.package = dk.uvTool "ruff"` runs the `uv.lock` Ruff for both hooks, and `dk.uvToolchain.uv` exposes the uv that `dk.uvTool` runs. ([#61](https://github.com/hakula139/devkit/pull/61))
- _(github)_ `ruleset` takes extra required checks after the repository, binding a bare context to GitHub Actions and `CONTEXT@APP-ID` to that app, for example `codecov/patch@254`. `--config` is removed. ([#67](https://github.com/hakula139/devkit/pull/67))
- _(github)_ The shared ruleset requires linear history, allows only squash merges, dismisses stale approvals on push, and no longer requires a branch to be up to date before merging. Before reapplying it with `ruleset`, confirm that the repository merges by squash only. ([#65](https://github.com/hakula139/devkit/pull/65))

### Fixed

- _(hooks)_ The dev shell hook reports on stderr, so `nix develop -c <cmd>` prints only the command's output on stdout, and `Swatinem/rust-cache` probing through `nix develop -c` no longer fails. ([#74](https://github.com/hakula139/devkit/pull/74))
- _(nushell)_ `mkNuApplication` commands, `nu-check`, `nu-test`, `changelog`, and `github` reject arguments that Nushell would parse as code, exiting 1 before Nushell runs. `docs/nushell.md` lists the rejected shapes. ([#62](https://github.com/hakula139/devkit/pull/62))
- _(setup-nix)_ Substituters that a caller adds through `extra_nix_config` now take effect. A plain `substituters` or `trusted-public-keys` line there replaces the `hakula` cache. ([#60](https://github.com/hakula139/devkit/pull/60))

[3.1.0]: https://github.com/hakula139/devkit/compare/v3.0.1...v3.1.0

## [3.0.1] - 2026-11-10

### Fixed

- _(hooks)_ `run-hooks` no longer runs a hook twice when git-hooks.nix assigns it to both the `pre-commit` and `pre-push` stages, as it does `trim-trailing-whitespace`. ([#52](https://github.com/hakula139/devkit/pull/52))

[3.0.1]: https://github.com/hakula139/devkit/compare/v3.0.0...v3.0.1

## [3.0.0] - 2026-11-09

### Breaking changes

- _(hooks)_ `preCommit` takes one `hooks` set and returns the dev shell, which runs every hook at commit time. `devHooks` and the `check` and `shell` outputs are removed, and `nix flake check` no longer runs hooks. `nix.yml` runs `nix develop -c run-hooks` on Linux and builds the dev shell on macOS, so `devShells.default` must include `preCommit`. Replace `preCommit.shell` with `preCommit` in `inputsFrom` and delete `checks.pre-commit = preCommit.check;`:

  ```nix
  devShells.default = pkgs.mkShell {
    inputsFrom = [ preCommit ];
  };
  ```

  Move every `devHooks` entry into `hooks`, delete CI steps that ran a hook's tool or installed its lockfile only for that hook, and verify locally with `nix develop -c run-hooks` as well as `nix flake check`. ([#49](https://github.com/hakula139/devkit/pull/49))

- _(hooks)_ A consumer's `args` and `excludes` append to the baseline's, and `lib.mkForce` replaces them. A custom `entry` keeps the baseline's `args`, so move any baseline flag it changed into `args = lib.mkForce [ ... ]`. Drop consumer `args` that repeat a baseline flag, including `eslint`'s and `tsc`'s new ones, since some tools reject a repeated flag. ([#49](https://github.com/hakula139/devkit/pull/49))

- _(hooks)_ An enabled `eslint` or `mypy` runs from the repository's pnpm or uv lockfile, so the custom `package`, `entry`, `files`, and `pass_filenames` that ran it that way can go. mypy checks only the `files` that `[tool.mypy]` names, so list them there. ([#49](https://github.com/hakula139/devkit/pull/49))

- _(hooks)_ `clippy` passes `--locked --all-targets`, so commit `Cargo.lock` or set `hooks.clippy.settings.extraArgs`. ([#49](https://github.com/hakula139/devkit/pull/49))

### Added

- _(hooks)_ `run-hooks [hook-id...]` runs the enabled `pre-commit`, `pre-merge-commit`, and `pre-push` hooks on every tracked file, or only the named hooks, after installing the pnpm and uv lockfiles that `dk.nodeTool` and `dk.uvTool` hooks run from, so `pnpm-workspace.yaml` no longer needs `verifyDepsBeforeRun`. ([#49](https://github.com/hakula139/devkit/pull/49))
- _(hooks)_ `tsc` works with `enable = true` alone, type-checking the project from the pnpm lockfile. Declare pnpm for `eslint` and `tsc` with `devEngines` in `package.json`, matching the major of `dk.nodeToolchain`'s pnpm, which changes only in a devkit major release. ([#49](https://github.com/hakula139/devkit/pull/49))

### Changed

- _(hooks)_ ESLint and clippy fail on warnings, and clippy no longer runs with `--offline`. ([#49](https://github.com/hakula139/devkit/pull/49))
- _(hooks)_ Prettier skips `pnpm-lock.yaml`, so a `.prettierignore` that lists only that file can go. ([#49](https://github.com/hakula139/devkit/pull/49))

[3.0.0]: https://github.com/hakula139/devkit/compare/v2.0.0...v3.0.0

## [2.0.0] - 2026-11-09

### Breaking changes

- _(hooks)_ Prettier and Taplo fall back to devkit's shared configuration when the source root has no `.prettierrc.json` or `.taplo.toml`, and markdownlint-cli2 always loads the shared rules, which a project's `.markdownlint-cli2.jsonc` files override rule by rule. A project whose markdownlint-cli2 configuration loads relative `customRules` or `markdownItPlugins` sets `hooks.markdownlint-cli2.settings.configPath = ".markdownlint-cli2.jsonc"`. ([#33](https://github.com/hakula139/devkit/pull/33))
- _(hooks)_ Baseline flags moved from `args` into `entry`, so a consumer's `args` adds to them and a consumer's `entry` replaces them. ([#45](https://github.com/hakula139/devkit/pull/45))
- Run `scripts/changelog.nu` and `scripts/github.nu` as `nix run github:hakula139/devkit/v2#changelog` and `#github`, which pin their tools in devkit's lock. `github.nu release-notes` is removed. ([#42](https://github.com/hakula139/devkit/pull/42))
- _(hooks)_ `ruff-format` runs its own `package`, so a project that overrides `ruff.package` sets `ruff-format.package` too. ([#34](https://github.com/hakula139/devkit/pull/34))

### Added

- _(hooks)_ `markdownlint-cli2`, `ruff`, `ruff-format`, and `taplo` accept `settings.configPath`, and `""` lets the tool find its own configuration. ([#33](https://github.com/hakula139/devkit/pull/33), [#47](https://github.com/hakula139/devkit/pull/47))
- _(lib)_ `nodeToolchain.nodejs` and `nodeToolchain.pnpm` expose the Node.js and pnpm that `nodeTool` uses. ([#35](https://github.com/hakula139/devkit/pull/35))

### Fixed

- _(hooks)_ The dev shell keeps the consumer's `PYTHONPATH`. ([#37](https://github.com/hakula139/devkit/pull/37))
- _(hooks)_ Ruff hooks also check type stubs and notebooks and apply the project's `exclude` and `extend-exclude` to explicitly passed paths. ([#34](https://github.com/hakula139/devkit/pull/34))
- _(hooks)_ An enabled lychee hook passes the hermetic `nix flake check` on Linux. ([#41](https://github.com/hakula139/devkit/pull/41))
- _(github)_ `ruleset` updates the ruleset named in its configuration, so a custom `--config` no longer overwrites `main` or adds a duplicate on each run. ([#40](https://github.com/hakula139/devkit/pull/40))

[2.0.0]: https://github.com/hakula139/devkit/compare/v1.1.0...v2.0.0

## [1.1.0] - 2026-11-08

### Added

- _(release)_ Generated changelog drafts support optional Highlights and linked `(#123)` pull request references, and group commits with `BREAKING CHANGE` footers under Breaking changes. ([#28](https://github.com/hakula139/devkit/pull/28))

### Fixed

- _(release)_ The shared release workflow validates the tag against the package version before waiting for CI, pinning caches, or publishing. Consumers can call it with one job. ([#31](https://github.com/hakula139/devkit/pull/31))

[1.1.0]: https://github.com/hakula139/devkit/compare/v1.0.0...v1.1.0

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
