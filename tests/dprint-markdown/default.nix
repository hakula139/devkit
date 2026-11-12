# ==================================================================================================
# Dprint Markdown Check
# ==================================================================================================

{
  pkgs,
  repo,
}:

let
  inherit (pkgs) lib;

  dprint-plugin-markdown =
    pkgs.callPackage (lib.path.append repo.root "nix/packages/dprint-plugin-markdown.nix")
      { };
  dprintConfig = import (lib.path.append repo.root "nix/hooks/dprint-config.nix") {
    inherit pkgs dprint-plugin-markdown;
  };
in
pkgs.runCommand "dprint-markdown"
  {
    nativeBuildInputs = [ pkgs.dprint ];
  }
  ''
    cp ${./fixtures/input.md} formatted.md
    chmod +w formatted.md
    export DPRINT_CACHE_DIR="$TMPDIR/dprint-cache"
    dprint fmt --config=${dprintConfig} formatted.md
    diff -u ${./fixtures/expected.md} formatted.md
    touch "$out"
  ''
