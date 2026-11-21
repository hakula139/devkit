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

## Pass application flags

Both builders accept application defaults through `flags`, where a string, integer, path, or derivation supplies one value for `--<name>`. Use `true` to enable a switch, `false` or `null` to omit it, and a list to repeat an option in the order given.

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
