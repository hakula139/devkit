# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  dk,
  skillSource,
}:
{
  nu-tooling = import ./nu-tooling { inherit pkgs dk; };
  skill-links = import ./skill-links { inherit pkgs skillSource; };
}
