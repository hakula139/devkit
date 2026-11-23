# ==================================================================================================
# Action Checks
# ==================================================================================================

{
  pkgs,
  dk,
  repo,
}:

let
  inherit (pkgs) lib;

  mkActionCheck =
    name:
    dk.nuTests {
      src = lib.path.append ./. name;
      runtimeInputs = [
        (dk.writeNuApplication {
          inherit name;
          text = builtins.readFile (lib.path.append repo.root ".github/actions/${name}/${name}.nu");
        })
      ];
    };
in
lib.genAttrs [
  "ci-result"
  "publish-release"
  "tagged-ci"
] mkActionCheck
