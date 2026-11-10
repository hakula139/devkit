# ==================================================================================================
# devkit Development Flake
# ==================================================================================================

{
  description = "Shared development tooling for Hakula's repositories";

  nixConfig = {
    extra-substituters = [
      "https://hakula.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hakula.cachix.org-1:7zwB3fhMfReHdOjh6DmnaLXgqbPDBcojvN9F+osZw0k="
    ];
  };

  # ------------------------------------------------------------------------------------------------
  # Inputs
  # ------------------------------------------------------------------------------------------------
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Outputs
  # ------------------------------------------------------------------------------------------------
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      git-hooks-nix,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      eachSystem =
        systemList: f:
        lib.zipAttrsWith (_: lib.mergeAttrsList) (
          map (system: lib.mapAttrs (_: value: { ${system} = value; }) (f system)) systemList
        );

      packageAtLeast =
        pkgs: name: version:
        if lib.versionAtLeast pkgs.${name}.version version then
          pkgs.${name}
        else
          nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.${name};

      skillHelpers = import ./nix/skill-links.nix { inherit lib; };
    in
    # ----------------------------------------------------------------------------------------------
    # Library
    # ----------------------------------------------------------------------------------------------
    {
      lib = {
        inherit eachSystem systems;
        inherit (skillHelpers) skillDirectoriesOption skillLinks skillSource;

        mkLib =
          pkgs:
          import ./nix/lib.nix {
            inherit pkgs git-hooks-nix;
            nushell = packageAtLeast pkgs "nushell" "0.116";
            ruff = packageAtLeast pkgs "ruff" "0.17";
            uv = packageAtLeast pkgs "uv" "0.13";
          };
      };
    }
    // eachSystem systems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        dk = self.lib.mkLib pkgs;

        scripts = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./.github/settings
            ./cliff.toml
            ./scripts
          ];
        };

        nuWrapper = import ./nix/nu-wrapper.nix {
          inherit pkgs;
          inherit (dk) nushell;
        };

        nuScript =
          name: runtimeInputs:
          nuWrapper.package {
            inherit name runtimeInputs;
            script = "${scripts}/scripts/${name}.nu";
          };

        preCommit = dk.preCommit {
          src = ./.;
          hooks = {
            doctoc.enable = true;
            lychee = {
              enable = true;
              settings.flags = "--offline";
            };
            nu-check.enable = true;
            prettier.enable = true;
            shellcheck.enable = true;
            shfmt.enable = true;
            taplo.enable = true;
          };
        };
      in
      {
        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        packages = {
          changelog = nuScript "changelog" [
            pkgs.gh
            pkgs.git
            pkgs.git-cliff
          ];
          github = nuScript "github" [
            pkgs.gh
          ];
        };

        # ------------------------------------------------------------------------------------------
        # Dev shell
        # ------------------------------------------------------------------------------------------
        devShells.default = pkgs.mkShell {
          name = "devkit-dev";
          packages = [
            dk.nushell
            dk.nu-test
          ];
          inputsFrom = [
            preCommit
          ];
        };

        # ------------------------------------------------------------------------------------------
        # Checks
        # ------------------------------------------------------------------------------------------
        checks = self.packages.${system} // {
          nu-tooling = pkgs.testers.testBuildFailure' {
            drv = dk.nuTests {
              src = ./tests;
              runtimeInputs = [
                dk.nu-check
              ];
            };
            expectedBuilderLogEntries = [
              "FAIL ./nu-tooling.test.nu: test fails on purpose"
              "4 passed, 1 failed"
            ];
          };
        };

        # ------------------------------------------------------------------------------------------
        # Formatter
        # ------------------------------------------------------------------------------------------
        formatter = pkgs.nixfmt-tree;
      }
    );
}
