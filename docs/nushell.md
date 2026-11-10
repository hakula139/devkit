# Nushell tooling

After [setting up the flake](flake.md), add the package and tests to the per-system output attribute set:

```nix
packages.default = dk.mkNuApplication {
  pname = "my-tool";
  version = "0.1.0";
  src = ./src;
  skills = [
    ./skills/my-tool
  ];
};

checks.tests = dk.nuTests {
  src = ./.;
};
```

[Nushell test runner](nu-test.md) covers `nu-test`, `nu-check`, and `nuTests`. `mkNuApplication` packages the application as follows:

- Reads its entry file from `<entry>.nu` at the `src` root, where `entry` defaults to `pname`, and installs it as `bin/<entry>` with `runtimeInputs` on its `PATH`.
- Packages the `.nu` files under `src`, leaving out `.test.nu`, `.stub.nu`, and `.testlib.nu`.
- Copies each `skills` directory to `share/skills/<basename>` through `devkit.lib.skillSource <directory>`, which drops those same suffixes from the skill.
- Sets `meta.mainProgram` to `entry` and merges any `meta` argument over it.

`writeNuApplication` packages a single-file command that needs no source directory, version, or skills:

```nix
packages.my-command = dk.writeNuApplication {
  name = "my-command";
  text = builtins.readFile ./my-command.nu;
  runtimeInputs = [
    pkgs.git
  ];
  makeWrapperArgs = [
    "--add-flag"
    "--verbose"
  ];
};
```

It installs `text` as `bin/<name>`, the name `--help` shows, with `runtimeInputs` on its `PATH`. It appends `makeWrapperArgs` to its `makeShellWrapper` call, so an argument added with `--add-flag` reaches `main` ahead of the caller's arguments. It sets `meta.mainProgram` to `name`, merging any `meta` argument over it as `mkNuApplication` does.

Both builders exit 1 before running the script on an argument that Nushell would parse as code. Nushell splices the arguments into the `main` call as source text, so the wrapper rejects an argument starting with `--` other than `--`, `--<name>`, and `--<name>=<value>` (where `<name>` is a letter followed by letters, digits, `_`, and `-`), a bare redirection such as `o>` or `e>>`, and an argument starting with `...$`. An operand of one of those shapes has to be passed in another form, such as an absolute path. Arguments that `makeWrapperArgs` adds bypass this check.

`mkNuApplication`, `writeNuApplication`, `nuTests`, and the `nu-*` tools run on `dk.nushell`, the Nushell that [`mkLib` selects](flake.md).

`devkit.lib` also provides the skill option and links for a Home Manager module:

```nix
options.programs.my-tool.skillDirectories = lib.mkOption devkit.lib.skillDirectoriesOption;

config = lib.mkIf cfg.enable {
  home.packages = [
    cfg.package
  ];
  home.file = devkit.lib.skillLinks {
    inherit (cfg) package;
    name = "my-tool";
    directories = cfg.skillDirectories;
  };
};
```

A skill link's `name` must equal its skill directory's basename.
