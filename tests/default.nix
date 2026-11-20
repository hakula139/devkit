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
  dprint-markdown = import ./dprint-markdown { inherit pkgs repo; };
  skill-links = import ./skill-links { inherit pkgs skillSource; };
}
// lib.mapAttrs' (name: lib.nameValuePair "nu-tooling-${name}") (
  import ./nu-tooling { inherit pkgs dk; }
)
