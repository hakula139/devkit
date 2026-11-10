# ==================================================================================================
# Nushell Wrapper
# ==================================================================================================

{
  pkgs,
  nushell,
}:

let
  inherit (pkgs) lib;

  # The build command that installs `bin` to run `script`, for a builder that has
  # `makeShellWrapper` in its `nativeBuildInputs`.
  command =
    {
      bin,
      script,
      runtimeInputs ? [ ],
      makeWrapperArgs ? [ ],
    }:
    let
      pathArgs = lib.optionalString (
        runtimeInputs != [ ]
      ) "--prefix PATH : ${lib.makeBinPath runtimeInputs}";
    in
    ''
      makeShellWrapper ${lib.getExe nushell} ${bin} \
        --run ${lib.escapeShellArg (builtins.readFile ./nu-wrapper.sh)} \
        --add-flags "--no-config-file ${script}" \
        ${pathArgs} \
        ${lib.escapeShellArgs makeWrapperArgs}
    '';
in
{
  inherit command;

  # A package whose `bin/<name>` runs `script` in place, which `--help` names by its basename.
  package =
    {
      name,
      script,
      runtimeInputs ? [ ],
      makeWrapperArgs ? [ ],
      meta ? { },
    }:
    pkgs.runCommand name
      {
        nativeBuildInputs = [
          pkgs.makeShellWrapper
        ];
        meta = {
          mainProgram = name;
        }
        // meta;
      }
      (command {
        bin = "$out/bin/${name}";
        inherit script runtimeInputs makeWrapperArgs;
      });
}
