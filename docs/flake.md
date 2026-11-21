# Nix flake

devkit needs nixpkgs 26.05 or later.

```nix
devkit = {
  url = "github:hakula139/devkit/v3";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Keep devkit's `nixpkgs-unstable` input independent of a stable `nixpkgs` so [`mkLib`](../flake.nix) has access to newer fallback tools.

Use `eachSystem` to define outputs for devkit's supported systems. Omit an output on systems where it cannot build.

```nix
outputs =
  {
    devkit,
    nixpkgs,
    ...
  }:
  devkit.lib.eachSystem devkit.lib.systems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      dk = devkit.lib.mkLib pkgs;

      preCommit = dk.preCommit {
        src = ./.;
      };
    in
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = [
          preCommit
        ];
      };
    }
  );
```

Add `/.pre-commit-config.yaml` to the repository's `.gitignore`, since the dev shell generates it. See [Hooks](hooks.md) to configure and run the hooks.
