# ==================================================================================================
# devkit Development Flake
# ==================================================================================================

{
  description = "Shared development tooling for Hakula's repositories";

  nixConfig = {
    extra-substituters = [ "https://hakula.cachix.org" ];
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
      nixpkgs,
      git-hooks-nix,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      # git-hooks.nix has dropped x86_64-darwin, which Nixpkgs supports only through 26.05.
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      eachSystem =
        systemList: f:
        let
          bySystem = lib.genAttrs systemList f;
          outputs = lib.unique (lib.concatMap builtins.attrNames (builtins.attrValues bySystem));

          collect =
            output:
            let
              hasOutput = system: builtins.hasAttr output bySystem.${system};
              supporting = builtins.filter hasOutput systemList;
            in
            lib.genAttrs supporting (system: bySystem.${system}.${output});
        in
        lib.genAttrs outputs collect;

      devkitLib = {
        inherit eachSystem systems;

        preCommit = import ./nix/hooks.nix { inherit git-hooks-nix; };

        mkDevShell = import ./nix/mk-dev-shell.nix;

        nodeHook = import ./nix/node-hook.nix;
      };
    in
    # ----------------------------------------------------------------------------------------------
    # Library
    # ----------------------------------------------------------------------------------------------
    {
      lib = devkitLib;
    }
    // eachSystem systems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        preCommit = devkitLib.preCommit {
          inherit pkgs;
          src = ./.;
        };
      in
      {
        # ------------------------------------------------------------------------------------------
        # Dev Shell
        # ------------------------------------------------------------------------------------------
        devShells.default = devkitLib.mkDevShell {
          inherit pkgs preCommit;
          marker = "default.json";
          packages = [ pkgs.git-cliff ];
        };

        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        packages.default = pkgs.emptyFile;

        # ------------------------------------------------------------------------------------------
        # Checks
        # ------------------------------------------------------------------------------------------
        checks = {
          pre-commit = preCommit.check;

          hook-systems =
            assert lib.all (system: builtins.hasAttr system git-hooks-nix.lib) devkitLib.systems;
            pkgs.emptyFile;

          shellcheck-zsh =
            (devkitLib.preCommit {
              inherit pkgs;
              src = ./nix/tests/shellcheck;
            }).check;

          hook-split =
            let
              split = devkitLib.preCommit {
                inherit pkgs;
                src = ./.;
                devHooks.dev-only = {
                  enable = true;
                  entry = "true";
                };
                checkHooks.check-only = {
                  enable = true;
                  entry = "true";
                };
                hooks.shared = {
                  enable = true;
                  entry = "true";
                };
                hooks.replaced = {
                  enable = true;
                  entry = "true";
                };
                devHooks.replaced = {
                  enable = true;
                  entry = "true";
                };
              };

              enabled =
                run:
                let
                  active = lib.filterAttrs (_: hook: hook.enable) run.config.hooks;
                in
                lib.attrNames active;
            in
            assert lib.elem "dev-only" (enabled split.dev);
            assert !(lib.elem "dev-only" (enabled split.check));
            assert lib.elem "check-only" (enabled split.check);
            assert !(lib.elem "check-only" (enabled split.dev));
            assert lib.elem "shared" (enabled split.dev);
            assert lib.elem "shared" (enabled split.check);
            assert lib.elem "replaced" (enabled split.dev);
            assert !(lib.elem "replaced" (enabled split.check));
            pkgs.emptyFile;

          each-system =
            let
              merged = devkitLib.eachSystem devkitLib.systems (
                system:
                let
                  extra = lib.optionalAttrs (system != "aarch64-darwin") { extra = system; };
                in
                { common = system; } // extra
              );
            in
            assert merged.common == lib.genAttrs devkitLib.systems (system: system);
            assert
              merged.extra == {
                aarch64-linux = "aarch64-linux";
                x86_64-linux = "x86_64-linux";
              };
            pkgs.emptyFile;

          dev-shell =
            let
              shell = devkitLib.mkDevShell {
                inherit pkgs preCommit;
                marker = "default.json";
                packages = [ pkgs.hello ];
                shellHook = "echo caller-hook";
              };

              withPassthru = devkitLib.mkDevShell {
                inherit pkgs preCommit;
                marker = "default.json";
                passthru.custom = "kept";
              };
            in
            assert lib.head shell.nativeBuildInputs == pkgs.hello;
            assert lib.last shell.nativeBuildInputs == preCommit.dev.config.package;
            assert shell.dontAddPythonPath;
            assert lib.hasInfix "core.hooksPath" shell.shellHook;
            assert lib.hasSuffix "echo caller-hook" shell.shellHook;
            assert withPassthru.custom == "kept";
            pkgs.emptyFile;

          node-hook =
            let
              nodejs = pkgs.runCommand "devkit-stub-nodejs" { } ''
                mkdir -p $out/bin
                printf '#!${pkgs.bash}/bin/bash\necho stub-nodejs\n' > $out/bin/node
                chmod +x $out/bin/node
              '';

              hook = devkitLib.nodeHook {
                inherit pkgs nodejs;
                command = "my-tool";
              };
            in
            pkgs.runCommand "devkit-node-hook"
              {
                nativeBuildInputs = [
                  pkgs.coreutils
                  pkgs.diffutils
                  pkgs.gnugrep
                ];
              }
              ''
                mkdir -p missing
                set +e
                (cd missing && ${hook} > output 2>&1)
                status=$?
                set -e
                [ "$status" -eq 1 ]
                grep -q 'node_modules is missing' missing/output

                mkdir -p present/node_modules/.bin
                cat > present/node_modules/.bin/my-tool <<'EOF'
                #!${pkgs.bash}/bin/bash
                node --version
                printf '%s|%s\n' "$@"
                EOF
                chmod +x present/node_modules/.bin/my-tool
                (cd present && ${hook} one two) > actual
                printf 'stub-nodejs\none|two\n' > expected
                diff expected actual
                touch "$out"
              '';

          ci-result =
            pkgs.runCommand "devkit-ci-result"
              {
                nativeBuildInputs = [
                  pkgs.diffutils
                  pkgs.jq
                ];
              }
              ''
                jq -r --argjson gate 1 -f ${./actions/ci-result/ci-result.jq} \
                  ${./nix/tests/ci-result/jobs.json} > actual
                printf '%s\n' '::error::cancelled-leg: cancelled' > expected
                diff expected actual
                touch "$out"
              '';
        };

        # ------------------------------------------------------------------------------------------
        # Formatter
        # ------------------------------------------------------------------------------------------
        formatter = pkgs.nixfmt-tree;
      }
    );
}
