# ==================================================================================================
# Hook Installation Check
# ==================================================================================================

{
  pkgs,
  preCommit,
}:

let
  inherit (pkgs) lib;

  # The sandbox cannot add GC roots, so the check supplies the config symlink itself.
  shellHook =
    lib.replaceStrings [ (lib.getExe' pkgs.nix "nix-store") ] [ "true" ]
      preCommit.shellHook;

  config = pkgs.writeText "pre-commit-config.yaml" ''
    repos:
      - repo: local
        hooks:
          - id: noop
            name: noop
            entry: 'true'
            language: system
            always_run: true
  '';
in
pkgs.runCommand "hooks-install"
  {
    nativeBuildInputs = [
      pkgs.git
      pkgs.pre-commit
    ];
    inherit config shellHook;
    script = ./hooks-install.sh;
  }
  ''
    mkdir -p "$out"
    bash "$script" "$config" "$shellHook"
  ''
