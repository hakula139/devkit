# ==================================================================================================
# Nushell Wrapper
# ==================================================================================================

# Returns the build command that installs `bin` to run `script` with Nushell, for a builder that
# has `makeShellWrapper` in its `nativeBuildInputs`.

{
  pkgs,
  nushell,
}:

{
  bin,
  script,
  runtimeInputs ? [ ],
}:

let
  inherit (pkgs) lib;

  pathArgs = lib.optionalString (
    runtimeInputs != [ ]
  ) "--prefix PATH : ${lib.makeBinPath runtimeInputs}";
in
''
  makeShellWrapper ${lib.getExe nushell} ${bin} \
    --run ${lib.escapeShellArg (builtins.readFile ./nu-wrapper.sh)} \
    --add-flags "--no-config-file ${script}" \
    ${pathArgs}
''
