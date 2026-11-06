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

        preCommit = dk.preCommit {
          src = ./.;
          hooks.nu-check.enable = true;
        };

        tools = pkgs.symlinkJoin {
          name = "devkit";
          paths = [
            dk.nu-check
            dk.nu-test
          ];
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

          actions = dk.nuTests {
            src = ./actions;
            runtimeInputs = [ pkgs.jq ];
          };

          nu-tools = pkgs.runCommand "devkit-nu-tools" { nativeBuildInputs = [ tools ]; } ''
            ${lib.getExe dk.nushell} --no-config-file ${./nix/tests}/nu-tools.nu
            touch "$out"
          '';

          nu-application =
            let
              version = "0.1.0";
              src = ./nix/tests/fixtures/nu-application;

              fixture = dk.mkNuApplication {
                inherit version src;
                pname = "devkit-fixture";
                entry = "greet";
                skills = [ (src + "/skills/fixture") ];
                runtimeInputs = [ pkgs.ripgrep ];
              };

              minimal = dk.mkNuApplication {
                inherit version src;
                pname = "greet";
              };

              links = self.lib.skillLinks {
                package = fixture;
                name = "fixture";
                directories = [ "skills" ];
              };
            in
            pkgs.runCommand "devkit-nu-application" { } ''
              [ "$(${lib.getExe fixture} Ada)" = "hello, Ada" ]
              [ -x ${lib.getExe minimal} ]
              [ "$(ls ${fixture}/share/devkit-fixture)" = greet ]
              [ -x ${fixture}/share/devkit-fixture/greet ]
              [ ! -e ${fixture}/share/skills/fixture/scripts/skipped.test.nu ]
              [ -x ${links."skills/fixture".source}/scripts/hello.sh ]
              touch "$out"
            '';
        };

        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        packages.default = tools;

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
            preCommit.shell
          ];
        };

        # ------------------------------------------------------------------------------------------
        # Formatter
        # ------------------------------------------------------------------------------------------
        formatter = pkgs.nixfmt-tree;
      }
    );
}
