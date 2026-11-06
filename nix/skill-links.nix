# ==================================================================================================
# Skill Links
# ==================================================================================================

{
  lib,
}:

let
  skipped = [
    ".test.nu"
    ".stub.nu"
    ".testlib.nu"
  ];
in
{
  skillDirectoriesOption = {
    type = lib.types.listOf lib.types.str;
    default = [
      ".agents/skills"
      ".claude/skills"
    ];
    description = "Home-relative directories that each receive a link to the skill directory.";
  };

  skillSource =
    skill:
    lib.fileset.toSource {
      root = skill;
      fileset = lib.fileset.fileFilter (
        file: !lib.any (suffix: lib.hasSuffix suffix file.name) skipped
      ) skill;
    };

  skillLinks =
    {
      package,
      name,
      directories,
    }:
    lib.genAttrs' directories (directory: {
      name = "${directory}/${name}";
      value.source = "${package}/share/skills/${name}";
    });
}
