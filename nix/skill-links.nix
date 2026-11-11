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

  packagedFile = file: !lib.any (suffix: lib.hasSuffix suffix file.name) skippedSuffixes;
in
{
  inherit packagedFile;

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
    lib.sources.cleanSourceWith {
      src = lib.fileset.toSource {
        root = skill;
        fileset = lib.fileset.fileFilter packagedFile skill;
      };
      # Matches baseline hooks' `(^|/)fixtures/` exclusion.
      filter = path: type: !(type == "directory" && baseNameOf path == "fixtures");
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
