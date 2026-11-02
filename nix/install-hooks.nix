# ==================================================================================================
# Dev-shell Hook Installer
# ==================================================================================================

{
  pkgs,
  preCommit,
  marker,
}:

let
  inherit (pkgs) lib;

  flock = lib.getExe pkgs.flock;
  git = lib.getExe pkgs.git;
in
''
  # git-hooks.nix sets a hooks path relative to the main checkout, which linked worktrees cannot
  # resolve (cachix/git-hooks.nix#688). Unset it to use the shared hooks directory. The lock
  # prevents concurrent loads from setting the path during `pre-commit install`, which rejects it.
  # Install only when the current repository is this project, since `nix develop` can borrow this
  # toolchain from a sibling repository.
  if common=$(${git} rev-parse --path-format=absolute --git-common-dir 2>/dev/null) &&
    top=$(${git} rev-parse --show-toplevel 2>/dev/null) &&
    [ -f "$top/${marker}" ]; then
    (
      ${flock} 9
      ${preCommit.config.installationScript}
      ${git} config --local --unset-all core.hooksPath || true
    ) 9>"$common/git-hooks.lock"
  fi
''
