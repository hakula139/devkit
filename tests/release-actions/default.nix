# ==================================================================================================
# Release Actions Check
# ==================================================================================================

{
  pkgs,
  repo,
}:

pkgs.runCommand "release-actions"
  {
    nativeBuildInputs = [ pkgs.bash ];
  }
  ''
    bash ${./release-actions.test.sh} ${repo.root}/.github/actions/publish-release/publish-release.sh
    touch "$out"
  ''
