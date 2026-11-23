# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  dk,
  repo,
  skillSource,
}:

let
  inherit (pkgs) lib;
in
{
  cachix-pin-tests = dk.nuTests {
    src = ../.github/actions/cachix-pin;
  };
  dprint-markdown = import ./dprint-markdown { inherit pkgs repo; };
  skill-links = import ./skill-links { inherit pkgs skillSource; };
}
// lib.mapAttrs' (name: lib.nameValuePair "nu-tooling-${name}") (
  import ./nu-tooling { inherit pkgs dk; }
)
