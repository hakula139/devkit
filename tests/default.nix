# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  dk,
  skillSource,
}:
{
  dprint-markdown = import ./dprint-markdown { inherit pkgs; };
  nu-tooling = import ./nu-tooling { inherit pkgs dk; };
  skill-links = import ./skill-links { inherit pkgs skillSource; };
}
