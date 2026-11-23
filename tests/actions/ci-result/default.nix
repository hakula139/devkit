# ==================================================================================================
# ci-result Check
# ==================================================================================================

{
  dk,
}:

let
  ci-result = dk.writeNuApplication {
    name = "ci-result";
    text = builtins.readFile ../../../.github/actions/ci-result/ci-result.nu;
  };
in
dk.nuTests {
  src = ./.;
  runtimeInputs = [
    ci-result
  ];
}
