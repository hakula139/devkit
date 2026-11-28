# Nushell tooling

## Package a project

After [setting up the flake](flake.md), use `dk.mkNuApplication` to package a Nushell source tree. Put `<entry>.nu` at the root of `src` and import sibling modules with relative paths. The entry defaults to `pname`, so the package below starts at `src/my-tool.nu`.

```nix
packages.default = dk.mkNuApplication {
  pname = "my-tool";
  version = "0.1.0";
  src = ./src;
};
```

List the packages that provide external commands in `runtimeInputs` and any skill directories to ship in `skills`, as in the [packaging example](../tests/nu-tooling/mk-nu-application/default.nix). To keep test code and skill fixtures out of the package, put test code in `.test.nu`, `.testlib.nu`, or `.stub.nu` files and fixtures under `fixtures/` in each skill. See the [builder](../nix/mk-nu-application.nix) for the packaging rules.

## Package a single file

Use `dk.writeNuApplication` for a standalone script without a source tree.

```nix
packages.my-command = dk.writeNuApplication {
  name = "my-command";
  text = builtins.readFile ./my-command.nu;
  runtimeInputs = [ pkgs.git ];
};
```

## Share modules

Nushell resolves named imports at parse time, so each environment needs the same module directories for `use config-file.nu` to find the same file.

| Where                                             | Setting                                     |
| ------------------------------------------------- | ------------------------------------------- |
| Both package builders                             | `libDirs`, in search order                  |
| [Nix test check](nu-test.md#run-the-check)        | `libDirs` in the call to `dk.nuTests`       |
| Dev shell                                         | `NU_LIB_DIRS`, absolute paths joined by `:` |
| Pre-commit hook, which runs outside the dev shell | `hooks.nu-check.settings.libDirs`           |

The [package and test example](../tests/nu-tooling/lib-dirs/default.nix) shows how to share module directories. If a directory also contains files the package should exclude, pass a filtered source built with `lib.fileset.toSource`.

## Check pinned versions

Add `dk.pinLibDir` to the dev shell's `NU_LIB_DIRS`, `hooks.nu-check.settings.libDirs`, and the `libDirs` passed to `dk.nuTests`. Each can then resolve the same static import. This example `check-pins.nu` reads a package definition from the checkout.

```nu
use pin-check.nu

def registry [] {
  let root = (pin-check repo-root "my-project")
  [
    {
      title: "Packages"
      pins: [
        {
          pin: "nushell"
          local: {|| pin-check nix-version $root "packages/nushell/default.nix" }
          upstream: {|| pin-check gh-latest-release "nushell/nushell" | str replace -r "^v" "" }
        }
      ]
    }
  ]
}

def "main list" [] {
  let footer = "Renovate owns the flake.lock inputs and the GitHub Actions refs."
  pin-check list {|| registry } --footer $footer
}

def "main check" [] { pin-check check {|| registry } }
def main [] { main check }
```

Run `nu check-pins.nu list` from a prepared dev shell to list the groups and pins in registry order. Keep the registry itself local so listing works offline. The optional `--footer` appends the repository's message after the groups. Only `check` needs an authenticated GitHub CLI and runs the `local` and `upstream` closures.

By default, matching values are current and different values are stale. To apply repository policy, give the row a `classify` closure that takes the pinned and upstream strings and returns a record such as `{status: "override redundant", outcome: "stale"}`. The table prints `status`. The summary counts rows by `outcome`, which must be `current`, `stale`, or `unknown`.

A failed lookup or an empty group counts as unknown. A blank string produces a `no value found` warning. If the lookup has already reported the cause, return `null` to mark the pin unknown without a second warning. An incomplete check exits `2`, even if other pins are stale. A complete check exits `1` if any pins are stale and `0` otherwise.

Use these [`pin-check` commands](../src/pin-checks/pin-check.nu) to build registry entries. GitHub queries take a repository in `owner/name` form. When a request fails, the checker prints a single warning with the pin name and the GitHub CLI error.

| Command                           | Result                                                                     |
| --------------------------------- | -------------------------------------------------------------------------- |
| `repo-root <checkout-name>`       | Current Git root, or an error naming the expected checkout and exit code 2 |
| `nix-attr <root> <file> <regex>`  | First match of the named capture `v`                                       |
| `nix-version <root> <file>`       | Value of a literal `version = "..."` in a Nix file                         |
| `gh-latest-release <repo>`        | Tag of GitHub's latest release                                             |
| `gh-releases <repo>`              | Non-draft release records, including their assets                          |
| `gh-newest-release <repo>`        | Highest version-shaped release tag, including prereleases                  |
| `gh-newest-tag-head <repo>`       | Commit SHA of the highest stable version tag                               |
| `gh-default-head <repo>`          | Commit SHA at the tip of the default branch                                |
| `version-at-least <left> <right>` | Whether the left version is at least the right one                         |
| `version-older <left> <right>`    | Whether the left version is older than the right one                       |
| `action-pins <root>`              | Sorted, unique external refs from GitHub workflows and actions             |
| `action-pin <ref>`                | Registry row delegating the ref to Renovate                                |

## Pass application flags

Both builders accept application defaults through `flags`, mapping each attribute name to `--<name>`.

| Value                                | Effect                                |
| ------------------------------------ | ------------------------------------- |
| String, integer, path, or derivation | Supplies one value for `--<name>`     |
| `true`                               | Enables the switch                    |
| `false` or `null`                    | Omits the flag                        |
| List                                 | Repeats the option in the order given |

Callers can override these defaults, including turning off a switch with `--verbose=false`. To fix an environment value in `writeNuApplication`, pass `--set` through `makeWrapperArgs`, as in the [single-file example](../tests/nu-tooling/write-nu-application/default.nix).

## Pass code-like arguments

Nushell parses some script arguments as code, so the [wrapper](../nix/nu-wrapper.sh) rejects malformed long options, bare redirection operators, and arguments starting with `...$`. Arguments supplied by `flags` or `makeWrapperArgs` bypass this check and must be trusted. For untrusted data, use stdin, an environment variable, or a file as described in the [Nushell argument conventions](https://github.com/hakulab/plugins/blob/main/plugins/hakula-languages/skills/nushell/SKILL.md#arguments).

## Link skills from Home Manager

The [skill helpers](../nix/skill-links.nix) define the Home Manager option and create the file links. Set `name` to the packaged skill directory's basename so the links point to that directory.

```nix
options.programs.my-tool.skillDirectories = lib.mkOption devkit.lib.skillDirectoriesOption;

config = lib.mkIf cfg.enable {
  home.packages = [ cfg.package ];
  home.file = devkit.lib.skillLinks {
    inherit (cfg) package;
    name = "my-tool";
    directories = cfg.skillDirectories;
  };
};
```
