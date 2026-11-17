# ==================================================================================================
# Nushell Wrapper
# ==================================================================================================

{
  pkgs,
  nushell,
}:

let
  inherit (pkgs) lib;
  esc = lib.escapeShellArg;

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
      target = if lib.hasPrefix "/" script then esc script else ''"$out/"${esc script}'';

      pathArgs = lib.optionals (runtimeInputs != [ ]) [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath runtimeInputs)
      ];

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
      makeShellWrapper ${esc (lib.getExe nushell)} "$out/"${esc bin} \
        --run ${esc (builtins.readFile ./nu-wrapper.sh)} \
        ${lib.escapeShellArgs pathArgs} \
        --add-flag --no-config-file \
        --add-flag ${target} \
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
          pkgs.buildPackages.makeShellWrapper
        ];
        meta = {
          mainProgram = name;
        }
        // meta;
      }
      (command {
        bin = "bin/${name}";
        inherit
          script
          runtimeInputs
          flags
          makeWrapperArgs
          ;
      });
}
