# Nushell tooling

## Package a project

After [setting up the flake](flake.md), use `dk.mkNuApplication` for a Nushell source tree. Put the entry script at `src/my-tool.nu` for this package.

```nix
packages.default = dk.mkNuApplication {
  pname = "my-tool";
  version = "0.1.0";
  src = ./src;
};
```

For a package that also ships skills, see the [packaging example](../tests/nu-tooling/mk-nu-application/default.nix) and the [builder](../nix/mk-nu-application.nix).

## Package a single file

```nix
packages.my-command = dk.writeNuApplication {
  name = "my-command";
  text = builtins.readFile ./my-command.nu;
  runtimeInputs = [ pkgs.git ];
};
```

Both builders accept `flags` for application defaults that callers can override. Nushell parses some arguments to a script as code. Pass untrusted data through stdin or a file, and use trusted values for wrapper-supplied arguments, which bypass the wrapper's argument check. See the [single-file example](../tests/nu-tooling/write-nu-application/default.nix) and the [argument check](../nix/nu-wrapper.sh).

## Share modules

For imports by module name, use the same `libDirs` in the package and its [Nix test check](nu-test.md#run-the-check). Pass a filtered source such as `lib.fileset.toSource` when a module directory contains files the package should exclude. See the [package and test example](../tests/nu-tooling/lib-dirs/default.nix).

Set `NU_LIB_DIRS` in the dev shell to the same absolute paths separated by `:`. The pre-commit hook runs outside that shell, so also set `hooks.nu-check.settings.libDirs`.

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
