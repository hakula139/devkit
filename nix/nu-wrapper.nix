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
      flags ? { },
      makeWrapperArgs ? [ ],
    }:
    let
      pathArgs = lib.optionalString (
        runtimeInputs != [ ]
      ) "--prefix PATH : ${lib.makeBinPath runtimeInputs}";
      flagArgs =
        lib.concatMap
          (arg: [
            "--add-flag"
            arg
          ])
          (
            lib.cli.toCommandLine (name: {
              option = "--${name}";
              sep = null;
              explicitBool = false;
              formatArg = toString;
            }) flags
          );
    in
    ''
      makeShellWrapper ${lib.getExe nushell} ${bin} \
        --run ${lib.escapeShellArg (builtins.readFile ./nu-wrapper.sh)} \
        --add-flags "--no-config-file ${script}" \
        ${pathArgs} \
        ${lib.escapeShellArgs (flagArgs ++ makeWrapperArgs)}
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
      flags ? { },
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
        inherit
          script
          runtimeInputs
          flags
          makeWrapperArgs
          ;
      });
}
