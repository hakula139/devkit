# ==================================================================================================
# nu-test Check
# ==================================================================================================

{
  pkgs,
  dk,
}:

let
  emptyTestsRejected =
    !(builtins.tryEval (
      dk.nuTests {
        src = ./fixtures/empty;
      }
    )).success;
in
assert emptyTestsRejected;
pkgs.testers.testBuildFailure' {
  drv = dk.nuTests {
    src = ./.;
    runtimeInputs = [
      dk.nu-test
    ];
  };
  expectedBuilderLogEntries = [
    "FAIL ./nu-test.test.nu: test fails on purpose"
    "4 passed, 1 failed"
  ];
}
