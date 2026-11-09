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

      nushellFor =
        pkgs:
        if lib.versionAtLeast pkgs.nushell.version "0.116" then
          pkgs.nushell
        else
          nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nushell;

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
            nushell = nushellFor pkgs;
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

        nuScript =
          name: runtimeInputs:
          pkgs.writeShellApplication {
            inherit name runtimeInputs;
            text = ''
              exec ${lib.getExe dk.nushell} --no-config-file ${scripts}/scripts/${name}.nu "$@"
            '';
          };

        preCommit = dk.preCommit {
          src = ./.;
          hooks = {
            actionlint.enable = true;
            check-yaml.enable = true;
            cspell.enable = true;
            deadnix.enable = true;
            doctoc.enable = true;
            dprint.enable = true;
            editorconfig-checker.enable = true;
            lychee = {
              enable = true;
              settings.flags = "--offline";
            };
            markdownlint-cli2.enable = true;
            nixfmt.enable = true;
            nu-check.enable = true;
            prettier.enable = true;
            shellcheck.enable = true;
            shfmt.enable = true;
            sort-file-contents.enable = true;
            statix.enable = true;
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
              "2 passed, 1 failed"
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
