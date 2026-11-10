# ==================================================================================================
# Hook Runner
# ==================================================================================================

{
  pkgs,
  hookType,
  hooksRun,
}:

let
  inherit (pkgs) lib;

  # `rawConfig` is git-hooks.nix's internal option holding the installed configuration.
  inherit (hooksRun.config) rawConfig;

  # ------------------------------------------------------------------------------------------------
  # Stages
  # ------------------------------------------------------------------------------------------------
  # Other stages need Git's hook arguments, such as a commit message file.
  fileStages = [
    "pre-commit"
    "pre-merge-commit"
    "pre-push"
  ];

  # Each hook runs once, in its first file stage, while installed hooks keep every stage.
  runStage = hook: lib.findFirst (stage: lib.elem stage (map hookType hook.stages)) null fileStages;

  rawHooks = lib.concatMap (repo: repo.hooks) rawConfig.repos;
  runStages = lib.intersectLists (map runStage rawHooks) fileStages;

  # ------------------------------------------------------------------------------------------------
  # Configuration
  # ------------------------------------------------------------------------------------------------
  runHook =
    hook:
    let
      stage = runStage hook;
    in
    hook // lib.optionalAttrs (stage != null) { stages = [ stage ]; };

  runRepo = repo: repo // { hooks = map runHook repo.hooks; };

  runConfig = pkgs.writers.writeJSON "run-hooks-config.json" (
    rawConfig // { repos = map runRepo rawConfig.repos; }
  );

  # ------------------------------------------------------------------------------------------------
  # Lockfile installation
  # ------------------------------------------------------------------------------------------------
  prepares = lib.unique (lib.catAttrs "prepare" hooksRun.enabledPackages);
in
pkgs.writeShellApplication {
  name = "run-hooks";
  runtimeInputs = [
    hooksRun.config.package
    hooksRun.config.gitPackage
  ];
  text = ''
    cd "$(git rev-parse --show-toplevel)"
    ${lib.concatMapStringsSep "\n" lib.getExe prepares}

    stages=(${lib.escapeShellArgs runStages})
    status=0
    for stage in "''${stages[@]}"; do
      prek run \
        --config ${runConfig} \
        --stage "$stage" \
        --all-files \
        --show-diff-on-failure \
        "$@" \
        || status=1
    done
    exit "$status"
  '';
}
