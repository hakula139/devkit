# ==================================================================================================
# Nushell Library Directories Check
# ==================================================================================================

{
  dk,
}:

let
  libDirs = [
    ./fixtures/first
    ./fixtures/second
  ];

  lib-command = dk.writeNuApplication {
    name = "lib-command";
    text = builtins.readFile ./lib-command.nu;
    inherit libDirs;
  };

  lib-app = dk.mkNuApplication {
    pname = "lib-app";
    version = "0.1.0";
    src = ./lib-app;
    libDirs = [
      ./fixtures/first
    ];
  };
in
dk.nuTests {
  src = ./.;
  inherit libDirs;
  runtimeInputs = [
    dk.nu-check
    lib-app
    lib-command
  ];
}
