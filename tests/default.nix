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
  pnpm-plugin = import ./pnpm-plugin { inherit pkgs dk repo; };
  release-actions = import ./release-actions { inherit pkgs repo; };
  skill-links = import ./skill-links { inherit pkgs skillSource; };
}
