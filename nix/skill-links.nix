# ==================================================================================================
# Skill Links
# ==================================================================================================

{
  lib,
}:

let
  skippedSuffixes = [
    ".test.nu"
    ".stub.nu"
    ".testlib.nu"
  ];

  packagedFile = name: !lib.any (suffix: lib.hasSuffix suffix name) skippedSuffixes;

  skillEntry =
    skill:
    if lib.isPath skill then
      {
        name = baseNameOf skill;
        src = skill;
      }
    else
      skill;
in
{
  inherit packagedFile skillEntry;

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
    lib.cleanSourceWith {
      inherit (skillEntry skill) name src;
      filter = path: type: type == "directory" || packagedFile (baseNameOf path);
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
