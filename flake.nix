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

    in
    # ----------------------------------------------------------------------------------------------
    # Library
    # ----------------------------------------------------------------------------------------------
    {
      lib = {
        inherit eachSystem systems;
        mkLib = pkgs: import ./nix/lib.nix { inherit pkgs git-hooks-nix; };
      };
    }
    // eachSystem systems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        dk = self.lib.mkLib pkgs;

        preCommit = dk.preCommit {
          src = ./.;
        };
      in
      {
        # ------------------------------------------------------------------------------------------
        # Checks
        # ------------------------------------------------------------------------------------------
        checks = {
          pre-commit = preCommit.check;

          shellcheck = pkgs.testers.testBuildFailure' {
            drv = (dk.preCommit { src = ./nix/tests/fixtures/shellcheck; }).check;
            expectedBuilderLogEntries = [ "SC2086" ];
          };

          hook-split =
            let
              mypy = dk.uvTool "mypy";
              prettier = dk.nodeTool "prettier";
              prettierFiles = "\\.json$";

              split = dk.preCommit {
                src = ./.;
                hooks = {
                  nu-check.enable = true;
                  prettier = {
                    enable = true;
                    files = prettierFiles;
                  };
                };
                devHooks = {
                  mypy = {
                    enable = true;
                    package = mypy;
                  };
                  prettier.package = prettier;
                };
              };

              checkHooks = split.check.config.hooks;
            in
            assert checkHooks.nu-check.enable;
            assert !checkHooks.mypy.enable && !checkHooks.prettier.enable;
            assert checkHooks.prettier.files == prettierFiles;
            pkgs.symlinkJoin {
              name = "devkit-hook-split";
              paths = [
                mypy
                prettier
              ];
            };

          dev-shell = preCommit.shell.overrideAttrs {
            buildPhase = ''
              export PYTHONPATH=/outer
              eval "$shellHook"
              [ -z "''${PYTHONPATH:-}" ]
              command -v prek
              touch "$out"
            '';
          };

          each-system =
            let
              merged = eachSystem systems (
                system: lib.optionalAttrs (system != "aarch64-darwin") { extra = system; }
              );
            in
            assert
              merged.extra == {
                aarch64-linux = "aarch64-linux";
                x86_64-linux = "x86_64-linux";
              };
            pkgs.emptyFile;
        };

        # ------------------------------------------------------------------------------------------
        # Dev shell
        # ------------------------------------------------------------------------------------------
        devShells.default = pkgs.mkShell {
          name = "devkit-dev";
          inputsFrom = [ preCommit.shell ];
        };

        # ------------------------------------------------------------------------------------------
        # Formatter
        # ------------------------------------------------------------------------------------------
        formatter = pkgs.nixfmt-tree;
      }
    );
}
