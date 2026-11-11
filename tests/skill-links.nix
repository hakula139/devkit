# ==================================================================================================
# Skill Links Check
# ==================================================================================================

{
  pkgs,
  skillSource,
}:

let
  source = skillSource ./skill-links/skill;
in
pkgs.runCommand "skill-links" { } ''
  test -f ${source}/SKILL.md
  test -f ${source}/agents/openai.yaml
  test -f ${source}/scripts/run.nu
  test -f ${source}/scripts/stores/read.nu
  test -f ${source}/examples/demo.test.nu/run.nu
  test ! -e ${source}/scripts/helpers
  test ! -e ${source}/fixtures
  test ! -e ${source}/scripts/stores/fixtures
  touch "$out"
''
