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
  flags ? { },
  meta ? { },
}:

let
  inherit (pkgs) lib;
  inherit (import ./skill-links.nix { inherit lib; }) packagedFile skillSource;
  nuWrapper = import ./nu-wrapper.nix { inherit pkgs nushell; };

  source = lib.fileset.toSource {
    root = src;
    fileset = lib.fileset.fileFilter (file: file.hasExt "nu" && packagedFile file) src;
  };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version;
  src = source;
  nativeBuildInputs = [
    pkgs.makeShellWrapper
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
    cp -r ${skillSource skill} $out/share/skills/${baseNameOf skill}
  '') skills
  + nuWrapper.command {
    bin = "$out/bin/${entry}";
    script = "$out/share/${pname}/${entry}";
    inherit runtimeInputs flags;
  };

  meta = {
    mainProgram = entry;
  }
  // meta;
}
