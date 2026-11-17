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
      label = "first";
      mode = "fast mode";
      optional = null;
      source = ./echo-args.nu;
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

  echo-app = dk.mkNuApplication {
    pname = "echo-app";
    version = "0.1.0";
    src = ./app;
    skills = [
      ./skill
    ];
    flags = {
      mode = "app mode";
    };
    meta.description = "Packaged echo-app test application";
  };

  emptyTestsRejected =
    !(builtins.tryEval (
      dk.nuTests {
        src = ./app;
      }
    )).success;
in
assert emptyTestsRejected;
pkgs.testers.testBuildFailure' {
  drv = dk.nuTests {
    src = ./.;
    runtimeInputs = [
      dk.nu-check
      dk.nu-test
      echo-app
      echo-args
    ];
  };
  expectedBuilderLogEntries = [
    "FAIL ./nu-tooling.test.nu: test fails on purpose"
    "11 passed, 1 failed"
  ];
}
