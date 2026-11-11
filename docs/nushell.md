# Nushell tooling

After [setting up the flake](flake.md), `dk` provides `mkNuApplication`, `writeNuApplication`, `nuTests`, and the `nu-*` tools, which run on `dk.nushell`, the Nushell that `mkLib` selects. [Nushell test runner](nu-test.md) covers `nu-test`, `nu-check`, and `nuTests`.

## Package a project

Add the package to the per-system output attribute set:

```nix
packages.default = dk.mkNuApplication {
  pname = "my-tool";
  version = "0.1.0";
  src = ./src;
  skills = [
    ./skills/my-tool
  ];
};
```

`mkNuApplication` packages the application as follows:

- Reads its entry file from `<entry>.nu` at the `src` root, where `entry` defaults to `pname`, and installs it as `bin/<entry>` with `runtimeInputs` on its `PATH`.
- Packages the `.nu` files under `src`, leaving out `.test.nu`, `.stub.nu`, and `.testlib.nu`.
- Copies each `skills` directory to `share/skills/<basename>` through `devkit.lib.skillSource <directory>`, which drops those same suffixes from the skill.
- Sets `meta.mainProgram` to `entry` and merges any `meta` argument over it.

## Package a single file

`writeNuApplication` packages a single-file command that needs no source directory, version, or skills:

```nix
packages.my-command = dk.writeNuApplication {
  name = "my-command";
  text = builtins.readFile ./my-command.nu;
  runtimeInputs = [
    pkgs.git
  ];
  flags = {
    verbose = true;
  };
};
```

It installs `text` as `bin/<name>`, the name `--help` shows, with `runtimeInputs` on its `PATH`. It sets `meta.mainProgram` to `name` and merges any `meta` argument over it.

## Pass application flags

Both builders take `flags`, which maps each attribute name to the application option `--<name>`:

```nix
flags = {
  config = ./config.json;
  count = 3;
  disabled = false;
  mode = "fast mode";
  tag = [
    "one"
    "two value"
  ];
  verbose = true;
};
```

This passes `--config <path> --count 3 --mode "fast mode" --tag one --tag "two value" --verbose`. A string, integer, path, or derivation passes its string form as the option's value, `true` passes the option alone, and `false` or `null` passes nothing. A list passes the option once per item in list order, and attributes are passed in sorted order. A value stays one argument even when it contains spaces.

The generated arguments reach `main` ahead of the caller's arguments, so a caller can override a generated value by passing the option again. A generated switch stays on unless the script takes an off switch, since a caller can only add arguments. `writeNuApplication` also takes `makeWrapperArgs`, which follows the generated flags in its `makeShellWrapper` call. Use it for wrapper operations such as `--set`, or for a raw argument that `flags` cannot generate:

```nix
makeWrapperArgs = [
  "--set"
  "MY_TOOL_HOME"
  "/var/lib/my-tool"

  "--add-flag"
  "--legacy"
];
```

## Pass code-like arguments

The `mkNuApplication` and `writeNuApplication` wrappers exit 1 before running the script on an argument that Nushell would parse as code:

- An argument starting with `--`, other than `--`, `--<name>`, and `--<name>=<value>`, where `<name>` is a letter followed by letters, digits, `_`, and `-`
- A bare redirection, such as `o>` or `e>>`
- An argument starting with `...$`

Pass such an operand in another form, such as an absolute path. Arguments that `flags` or `makeWrapperArgs` add bypass this check.

## Link skills from Home Manager

`devkit.lib` provides the skill option and links for a Home Manager module:

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
