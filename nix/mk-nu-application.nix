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
  esc = lib.escapeShellArg;
  nuWrapper = import ./nu-wrapper.nix { inherit pkgs nushell; };

  appDir = "share/${pname}";
  entryScript = "${appDir}/${entry}";

  source = lib.fileset.toSource {
    root = src;
    fileset = lib.fileset.fileFilter (file: file.hasExt "nu" && packagedFile file) src;
  };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version;
  nativeBuildInputs = [
    pkgs.buildPackages.makeShellWrapper
  ];

  buildCommand = ''
    mkdir -p "$out/"${esc appDir}
    cp -r --no-preserve=mode ${esc source}/. "$out/"${esc appDir}
    # Nushell names `main` after the script file in `--help`.
    mv "$out/"${esc "${entryScript}.nu"} "$out/"${esc entryScript}
  ''
  + lib.optionalString (skills != [ ]) ''
    mkdir -p "$out/share/skills"
  ''
  + lib.concatMapStrings (skill: ''
    cp -r ${esc (skillSource skill)} "$out/"${esc "share/skills/${baseNameOf skill}"}
  '') skills
  + nuWrapper.command {
    bin = "bin/${entry}";
    script = entryScript;
    inherit runtimeInputs flags;
  };

  meta = {
    mainProgram = entry;
  }
  // meta;
}
