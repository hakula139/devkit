# ==================================================================================================
# Nushell Tooling Check
# ==================================================================================================

{
  pkgs,
  dk,
}:

let
  json = pkgs.formats.json { };

  echo-args-config = json.generate "echo-args-config.json" {
    service = {
      endpoint = "https://example.com/api";
      retries = 2;
    };
  };

  echo-args = dk.writeNuApplication {
    name = "echo-args";
    text = builtins.readFile ./echo-args.nu;
    flags = {
      baked = true;
      config = echo-args-config;
      count = 3;
      disabled = false;
      mode = "fast mode";
      optional = null;
      tag = [
        "one"
        "two value"
      ];
    };
    makeWrapperArgs = [
      "--set"
      "DEVKIT_ECHO_ARGS_TEST_VALUE"
      "wrapper"

      "--add-flag"
      "--raw"
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
    "6 passed, 1 failed"
  ];
}
