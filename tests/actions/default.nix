# ==================================================================================================
# Action Checks
# ==================================================================================================

{
  dk,
}:
{
  ci-result = import ./ci-result { inherit dk; };
  publish-release = import ./publish-release { inherit dk; };
  tagged-ci = import ./tagged-ci { inherit dk; };
}
