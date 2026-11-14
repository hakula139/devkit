# ==================================================================================================
# pnpm Configuration Plugin Check
# ==================================================================================================

{
  pkgs,
  dk,
  repo,
}:

pkgs.runCommand "pnpm-plugin"
  {
    nativeBuildInputs = [ dk.nodeToolchain.nodejs ];
  }
  ''
    node --test ${repo.root}/tests/pnpm-plugin/pnpm-plugin.test.mjs
    touch "$out"
  ''
