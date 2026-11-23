# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  dk,
  repo,
  packages,
  skillSource,
}:

let
  inherit (pkgs) lib;
in
{
  dprint-markdown = import ./dprint-markdown { inherit pkgs repo; };
  skill-links = import ./skill-links { inherit pkgs skillSource; };
}
// lib.mapAttrs' (name: lib.nameValuePair "actions-${name}") (
  import ./actions { inherit pkgs dk repo; }
)
// lib.mapAttrs' (name: lib.nameValuePair "nu-tooling-${name}") (
  import ./nu-tooling { inherit pkgs dk; }
)
// lib.mapAttrs' (name: lib.nameValuePair "scripts-${name}") (
  import ./scripts { inherit dk packages; }
)
