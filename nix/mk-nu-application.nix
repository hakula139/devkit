# ==================================================================================================
# Nushell Application
# ==================================================================================================

{
  pkgs,
  nushell,
}:

{
  pname,
  version,
  src,
  entry ? pname,
  skills ? [ ],
  runtimeInputs ? [ ],
  meta ? { },
}:

let
  inherit (pkgs) lib;
  inherit (import ./skill-links.nix { inherit lib; }) packagedFile skillEntry skillSource;

  source = lib.fileset.toSource {
    root = src;
    fileset = lib.fileset.fileFilter (file: file.hasExt "nu" && packagedFile file.name) src;
  };

  pathArgs = lib.optionalString (
    runtimeInputs != [ ]
  ) "--prefix PATH : ${lib.makeBinPath runtimeInputs}";
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version;
  src = source;
  nativeBuildInputs = [
    pkgs.makeBinaryWrapper
  ];
  dontBuild = true;

  # Nushell names `main` after the script file in `--help`.
  installPhase = ''
    mkdir -p $out/share/${pname}
    cp -r . $out/share/${pname}
    mv $out/share/${pname}/${entry}.nu $out/share/${pname}/${entry}
  ''
  + lib.concatMapStrings (skill: ''
    mkdir -p $out/share/skills
    cp -r ${skillSource skill} $out/share/skills/${skill.name}
  '') (map skillEntry skills)
  + ''
    makeWrapper ${lib.getExe nushell} $out/bin/${entry} \
      --add-flags "--no-config-file $out/share/${pname}/${entry}" \
      ${pathArgs}
  '';

  meta = {
    mainProgram = entry;
  }
  // meta;
}
