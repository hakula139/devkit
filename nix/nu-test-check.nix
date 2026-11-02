# ==================================================================================================
# Nushell Test Check
# ==================================================================================================

{
  pkgs,
  nushell,
  nu-test,
}:

{
  src,
  runtimeInputs ? [ ],
}:

let
  inherit (pkgs) lib;

  isTest = file: lib.hasSuffix ".test.nu" file.name;
  tests = lib.fileset.toList (lib.fileset.fileFilter isTest src);

  source = lib.fileset.toSource {
    root = src;
    fileset = lib.fileset.unions (map dirOf tests);
  };

  testPaths = map (test: lib.path.removePrefix src test) tests;
in
pkgs.runCommand "nu-tests"
  {
    nativeBuildInputs = [
      nushell
      nu-test
    ]
    ++ runtimeInputs;
  }
  ''
    cd ${source}
    nu-test ${lib.escapeShellArgs testPaths}
    touch "$out"
  ''
