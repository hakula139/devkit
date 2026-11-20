# ==================================================================================================
# mkNuApplication Check
# ==================================================================================================

{
  dk,
}:

let
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
in
dk.nuTests {
  src = ./.;
  runtimeInputs = [
    echo-app
  ];
}
