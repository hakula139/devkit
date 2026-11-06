#!/usr/bin/env bash

# ==================================================================================================
# CI Result
# ==================================================================================================

set -euo pipefail

# `needs` misses a matrix leg cancelled before it starts, so read each job from the API.
failed=$(
  gh api "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/attempts/$GITHUB_RUN_ATTEMPT/jobs?per_page=100" \
    --paginate \
    --slurp \
    | jq \
      -r \
      --argjson gate "$GATE_ID" \
      -f "$GITHUB_ACTION_PATH/ci-result.jq"
)

if [[ -n "$failed" ]]; then
  echo "$failed"
  exit 1
fi
