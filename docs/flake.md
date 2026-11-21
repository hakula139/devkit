# Nix flake

devkit needs nixpkgs 26.05 or later.

```nix
devkit = {
  url = "github:hakula139/devkit/v3";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Keep devkit's `nixpkgs-unstable` input independent of a stable `nixpkgs`. For Nushell, Ruff, and uv, [`mkLib`](../flake.nix) selects a newer tool from that fallback input only when the consumer's version falls below its minimum.

Use `devkit.lib.eachSystem` with `devkit.lib.systems` to define per-system outputs. Omit an output on systems where it cannot build. Inside the callback, bind `dk = devkit.lib.mkLib pkgs` once to get helpers built for that system's package set.

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
