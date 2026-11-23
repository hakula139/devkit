# ==================================================================================================
# publish-release Check
# ==================================================================================================

{
  dk,
}:

let
  publish-release = dk.writeNuApplication {
    name = "publish-release";
    text = builtins.readFile ../../../.github/actions/publish-release/publish-release.nu;
  };
in
dk.nuTests {
  src = ./.;
  runtimeInputs = [
    publish-release
  ];
}
