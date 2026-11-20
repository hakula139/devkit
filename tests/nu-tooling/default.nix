# ==================================================================================================
# Nushell Tooling Checks
# ==================================================================================================

{
  pkgs,
  dk,
}:
{
  lib-dirs = import ./lib-dirs { inherit dk; };
  mk-nu-application = import ./mk-nu-application { inherit dk; };
  nu-check = import ./nu-check { inherit dk; };
  nu-test = import ./nu-test { inherit pkgs dk; };
  write-nu-application = import ./write-nu-application { inherit pkgs dk; };
}
