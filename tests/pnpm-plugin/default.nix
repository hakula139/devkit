# ==================================================================================================
# pnpm Configuration Plugin Check
# ==================================================================================================

{
  pkgs,
  dk,
  repo,
}:

let
  inherit (pkgs) lib;

  source = lib.fileset.toSource {
    inherit (repo) root;
    fileset = lib.fileset.unions [
      (lib.path.append repo.root "package.json")
      (lib.path.append repo.root "pnpmfile.mjs")
      ./.
    ];
  };
in
pkgs.runCommand "pnpm-plugin"
  {
    nativeBuildInputs = [ dk.nodeToolchain.nodejs ];
  }
  ''
    node --test ${source}/tests/pnpm-plugin/pnpm-plugin.test.mjs
    touch "$out"
  ''
