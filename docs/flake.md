# Nix flake

devkit needs nixpkgs 26.05 or later.

```nix
devkit = {
  url = "github:hakula139/devkit/v3";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`mkLib` takes Nushell, Ruff, and uv from the consumer's nixpkgs when they are at least 0.116, 0.17, and 0.13, and otherwise from devkit's `nixpkgs-unstable` input, so `nixpkgs-unstable` must not follow a stable nixpkgs.

`devkit.lib.systems` and `devkit.lib.eachSystem` replace `flake-utils`:

- `devkit.lib.systems` lists the shared target systems.
- `devkit.lib.eachSystem` merges each system's attribute set, leaving any output that a system omits absent on that system.

```nix
outputs =
  {
    self,
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
        name = "my-tool-dev";
        packages = [
          pkgs.ripgrep
        ];
        inputsFrom = [
          preCommit
        ];
      };
    }
  );
```

`devkit.lib` holds the pure helpers, and `dk = devkit.lib.mkLib pkgs` binds `pkgs` once for the rest. See [Hooks](hooks.md) for hook setup and configuration.

Add `/.pre-commit-config.yaml` to the repository's `.gitignore`, since the dev shell generates it.
