# ==================================================================================================
# Dev Shell
# ==================================================================================================

{
  pkgs,
  preCommit,
  marker,
  packages ? [ ],
  shellHook ? "",
  ...
}@args:

let
  installHooks = import ./install-hooks.nix {
    inherit pkgs marker;
    preCommit = preCommit.dev;
  };

  shellArgs =
    builtins.removeAttrs args [
      "pkgs"
      "preCommit"
      "marker"
      "packages"
      "shellHook"
    ]
    // {
      packages = packages ++ preCommit.dev.enabledPackages ++ [ preCommit.dev.config.package ];
      dontAddPythonPath = true;
      shellHook = installHooks + shellHook;
    };
in
pkgs.mkShell shellArgs
