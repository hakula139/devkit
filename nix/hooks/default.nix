# ==================================================================================================
# Pre-commit Hooks
# ==================================================================================================

{
  pkgs,
  git-hooks-nix,
  actionlint,
  nodeTool,
  nu-check,
  ruff,
  uvTool,
}:

{
  src,
  hooks ? { },
  excludes ? [ ],
}:

let
  inherit (pkgs) lib;

  # ------------------------------------------------------------------------------------------------
  # Hook modules
  # ------------------------------------------------------------------------------------------------
  inherit (import ./options.nix { inherit lib; }) configEntry configPathOptions;

  baseline = import ./baseline.nix {
    inherit
      pkgs
      src
      actionlint
      configEntry
      nodeTool
      nu-check
      ruff
      uvTool
      ;
  };

  # ------------------------------------------------------------------------------------------------
  # Hook evaluation
  # ------------------------------------------------------------------------------------------------
  # Mirrors git-hooks.nix's own overlay, so the hooks build from the consumer's package set.
  gitHooksRun = pkgs.callPackage "${git-hooks-nix}/nix/run.nix" {
    tools = import "${git-hooks-nix}/nix/call-tools.nix" pkgs;
    isFlakes = true;
  };

  hooksRun = gitHooksRun {
    inherit src;
    package = pkgs.prek;
    imports = [
      configPathOptions
      baseline
      { inherit hooks excludes; }
    ];
  };

  hookType =
    stage:
    if
      lib.elem stage [
        "commit"
        "merge-commit"
        "push"
      ]
    then
      "pre-${stage}"
    else
      stage;

  # ------------------------------------------------------------------------------------------------
  # Hook runner
  # ------------------------------------------------------------------------------------------------
  runHooks = import ./run-hooks.nix { inherit pkgs hookType hooksRun; };

  # ------------------------------------------------------------------------------------------------
  # Hook installation
  # ------------------------------------------------------------------------------------------------
  git = lib.getExe hooksRun.config.gitPackage;
  hookTypes = lib.unique (map hookType (lib.remove "manual" hooksRun.config.installStages));
in
pkgs.mkShell {
  # Listed directly, the hook packages' setup hooks would set the consumer's PYTHONPATH.
  # A colliding executable keeps the first package's, matching the PATH order of a plain list.
  packages = [
    (pkgs.buildEnv {
      name = "pre-commit-hook-tools";
      paths = hooksRun.enabledPackages;
      pathsToLink = [ "/bin" ];
      ignoreCollisions = true;
    })
    runHooks
    hooksRun.config.package
  ];

  shellHook = ''
    if top=$(${git} rev-parse --show-toplevel 2>/dev/null); then
      # Linked worktrees share hooks, so their common Git directory owns the install lock.
      common=$(
        ${git} rev-parse \
          --path-format=absolute \
          --git-common-dir
      )

      # Callers of `nix develop -c` read the command's stdout, so the install reports on stderr.
      (
        set -e
        ${lib.getExe pkgs.flock} 9

        # Keep hook tools alive through the config's GC root.
        # Nix refuses to replace an existing regular file.
        ${lib.getExe' pkgs.nix "nix-store"} \
          --add-root "$top/${hooksRun.config.configPath}" \
          --indirect \
          --realise ${hooksRun.config.configFile}

        # Refresh shims even with unchanged config, preserving core.hooksPath.
        # Empty stage arguments would make prek install pre-commit by default.
        ${lib.optionalString (hookTypes != [ ]) ''
          ${lib.getExe hooksRun.config.package} install \
            --overwrite \
            --config ${lib.escapeShellArg hooksRun.config.configPath} \
            ${lib.escapeShellArgs (
              lib.concatMap (type: [
                "--hook-type"
                type
              ]) hookTypes
            )}
        ''}
      ) 9>"$common/git-hooks.lock" >&2
    fi
  '';
}
