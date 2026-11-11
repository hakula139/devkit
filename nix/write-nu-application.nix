# ==================================================================================================
# Nushell Single-File Application
# ==================================================================================================

{
  pkgs,
  nushell,
}:

let
  nuWrapper = import ./nu-wrapper.nix { inherit pkgs nushell; };
in
{
  name,
  text,
  runtimeInputs ? [ ],
  flags ? { },
  makeWrapperArgs ? [ ],
  meta ? { },
}:

# Nushell names `main` after the script file in `--help`.
nuWrapper.package {
  inherit
    name
    runtimeInputs
    flags
    makeWrapperArgs
    meta
    ;
  script = "${pkgs.writeTextDir name text}/${name}";
}
