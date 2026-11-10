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
- Copies each `skills` entry to `share/skills/<name>` through `devkit.lib.skillSource <entry>`, which drops those same suffixes from the skill. A path entry's name is its basename.
- Sets `meta.mainProgram` to `entry` and merges any `meta` argument over it.

A skill whose directory has another basename, such as a repository whose root is the skill, takes a `{ name; src; }` entry, where `src` is a path or a `lib.fileset.toSource` result:

```nix
skills = [
  {
    name = "my-tool";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./SKILL.md
        ./agents
      ];
    };
  }
];
```

`mkNuApplication`, `nuTests`, and the `nu-*` tools run on `dk.nushell`, which is the consumer's `pkgs.nushell` when it is 0.116 or later, and otherwise the one from devkit's `nixpkgs-unstable` input, so `nixpkgs-unstable` must not follow a stable nixpkgs.

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

A skill link's `name` must equal its skill entry's name.
