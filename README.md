# devkit

[![CI](https://github.com/hakula139/devkit/actions/workflows/ci.yml/badge.svg)](https://github.com/hakula139/devkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![WakaTime coding time for devkit](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/04be7427-93da-43cd-8ed9-4d1f7e35987a.svg)

Shared development tooling for Hakula's repositories.

## Documentation

| Document                       | Description                             |
| ------------------------------ | --------------------------------------- |
| [Nix flake][flake]             | Flake inputs, shared helpers, dev shell |
| [Hooks][hooks]                 | Pre-commit setup and configuration      |
| [Nushell tooling][nushell]     | Application and skill packaging         |
| [Nushell test runner][nu-test] | Tests and script checks                 |
| [CI workflow and gate][ci]     | Nix checks and required status gate     |
| [Releasing][releasing]         | Release setup and publishing            |
| [Renovate preset][renovate]    | Dependency updates and automerge        |
| [GitHub conventions][github]   | Repository settings, rulesets, labels   |
| [Development][development]     | Contributor instructions                |

## License

Copyright (c) 2026 [Hakula](https://hakula.xyz). Licensed under the [MIT License](LICENSE).

[flake]: docs/flake.md
[hooks]: docs/hooks.md
[nushell]: docs/nushell.md
[nu-test]: docs/nu-test.md
[ci]: docs/ci.md
[releasing]: docs/releasing.md
[renovate]: docs/renovate.md
[github]: docs/github.md
[development]: AGENTS.md
