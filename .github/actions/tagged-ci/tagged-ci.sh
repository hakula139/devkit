#!/usr/bin/env bash

# ==================================================================================================
# Tagged CI
# ==================================================================================================

set -euo pipefail

while true; do
  if ! verdict=$(
    gh api "repos/$GITHUB_REPOSITORY/actions/workflows/ci.yml/runs?head_sha=$GITHUB_SHA&per_page=100" \
      --paginate \
      --slurp \
      | jq \
        -r \
        -f "$GITHUB_ACTION_PATH/tagged-ci.jq"
  ); then
    echo "::error::Could not read the runs of .github/workflows/ci.yml, which tagged-ci waits for."
    exit 1
  fi

  case "$verdict" in
    passed*)
      echo "CI passed on $GITHUB_SHA: ${verdict#passed }"
      exit 0
      ;;
    running)
      sleep 30
      ;;
    *)
      echo "::error::No push or dispatched CI run passed on $GITHUB_SHA." \
        "Rerun the failed CI jobs, or run 'gh workflow run ci.yml --ref $GITHUB_REF_NAME'," \
        "then rerun this job."
      exit 1
      ;;
  esac
done
