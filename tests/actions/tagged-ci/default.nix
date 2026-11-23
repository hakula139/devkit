# ==================================================================================================
# tagged-ci Check
# ==================================================================================================

{
  dk,
}:

let
  tagged-ci = dk.writeNuApplication {
    name = "tagged-ci";
    text = builtins.readFile ../../../.github/actions/tagged-ci/tagged-ci.nu;
  };
in
dk.nuTests {
  src = ./.;
  runtimeInputs = [
    tagged-ci
  ];
}
