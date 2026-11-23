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

  mkAction =
    name:
    dk.writeNuApplication {
      inherit name;
      text = builtins.readFile (lib.path.append repo.root ".github/actions/${name}/${name}.nu");
    };
in
dk.nuTests {
  src = ./.;
  runtimeInputs = map mkAction [
    "ci-result"
    "publish-release"
    "tagged-ci"
  ];
}
