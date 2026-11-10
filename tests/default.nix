# ==================================================================================================
# Nushell Tooling Check
# ==================================================================================================

{
  pkgs,
  dk,
}:

let
  echo-args = dk.writeNuApplication {
    name = "echo-args";
    text = builtins.readFile ./echo-args.nu;
    makeWrapperArgs = [
      "--add-flag"
      "--baked"
    ];
  };
in
pkgs.testers.testBuildFailure' {
  drv = dk.nuTests {
    src = ./.;
    runtimeInputs = [
      dk.nu-check
      echo-args
    ];
  };
  expectedBuilderLogEntries = [
    "FAIL ./nu-tooling.test.nu: test fails on purpose"
    "5 passed, 1 failed"
  ];
}
