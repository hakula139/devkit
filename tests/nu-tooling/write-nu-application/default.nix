# ==================================================================================================
# writeNuApplication Check
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
in
dk.nuTests {
  src = ./.;
  runtimeInputs = [
    dk.nu-check
    echo-args
  ];
}
