# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  dk,
  repo,
  skillSource,
}:
{
  dprint-markdown = import ./dprint-markdown { inherit pkgs repo; };
  nu-tooling = import ./nu-tooling { inherit pkgs dk; };
  skill-links = import ./skill-links { inherit pkgs skillSource; };
}
