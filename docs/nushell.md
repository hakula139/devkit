# Nushell tooling

## Package a project

After [setting up the flake](flake.md), use `dk.mkNuApplication` for a Nushell source tree. Put `<entry>.nu` at the root of `src` and use relative imports for sibling modules. The entry defaults to `pname`, so this package starts at `src/my-tool.nu`.

```nix
packages.default = dk.mkNuApplication {
  pname = "my-tool";
  version = "0.1.0";
  src = ./src;
};
```

Use `runtimeInputs` for executables the command calls and `skills` for skill directories to ship with it. Keep test-only code in `.test.nu`, `.testlib.nu`, or `.stub.nu` files and skill fixtures under `fixtures/` so they stay out of the package. See the [packaging example](../tests/nu-tooling/mk-nu-application/default.nix) and the [builder](../nix/mk-nu-application.nix).

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

Nushell resolves named imports at parse time. Supply the same module directories in each environment so `use config-file.nu` finds the same file everywhere.

| Where                                             | Setting                                     |
| ------------------------------------------------- | ------------------------------------------- |
| Both package builders                             | `libDirs`, in search order                  |
| [Nix test check](nu-test.md#run-the-check)        | `libDirs` in the call to `dk.nuTests`       |
| Dev shell                                         | `NU_LIB_DIRS`, absolute paths joined by `:` |
| Pre-commit hook, which runs outside the dev shell | `hooks.nu-check.settings.libDirs`           |

Pass a filtered source such as `lib.fileset.toSource` when a module directory contains files the package should exclude. See the [package and test example](../tests/nu-tooling/lib-dirs/default.nix).

## Pass application flags

Both builders accept `flags` for application defaults. A string, integer, path, or derivation supplies one value for `--<name>`. Use `true` for a switch, `false` or `null` to omit it, and a list to repeat the option in list order. Callers can override a default, including a switch with `--verbose=false`. For a fixed environment value in `writeNuApplication`, use `makeWrapperArgs` with `--set`. See the [single-file example](../tests/nu-tooling/write-nu-application/default.nix).

## Pass code-like arguments

Nushell parses some script arguments as code. The [wrapper](../nix/nu-wrapper.sh) rejects malformed long options, bare redirection operators, and arguments starting with `...$`. Pass untrusted data through stdin, an environment variable, or a file. Arguments supplied by `flags` or `makeWrapperArgs` bypass the check and must be trusted. See the [Nushell argument conventions](https://github.com/hakulab/plugins/blob/main/plugins/hakula-languages/skills/nushell/SKILL.md#arguments).

## Link skills from Home Manager

Use the packaged skill directory's basename for `name`. The [skill helpers](../nix/skill-links.nix) define the option and produce the file links.

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
