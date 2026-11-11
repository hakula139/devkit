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

  packagedName = name: !lib.any (suffix: lib.hasSuffix suffix name) skippedSuffixes;
in
{
  packagedFile = file: packagedName file.name;

  skillDirectoriesOption = {
    type = lib.types.listOf lib.types.str;
    default = [
      ".agents/skills"
      ".claude/skills"
    ];
    description = "Home-relative directories that each receive a link to the skill directory.";
  };

  # Prune `fixtures` directories directly: filtering their files leaves the empty directories in
  # the store. Matches baseline hooks' `(^|/)fixtures/` exclusion.
  skillSource =
    skill:
    let
      rootPrefix = "${toString skill}/";

      packagedPath =
        path: type:
        let
          relativePath = lib.removePrefix rootPrefix (toString path);
        in
        packagedName (baseNameOf path)
        && !(type == "directory" && lib.elem "fixtures" (lib.splitString "/" relativePath));
    in
    lib.sources.cleanSourceWith {
      src = skill;
      filter = packagedPath;
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
