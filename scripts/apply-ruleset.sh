#!/usr/bin/env bash

# ==================================================================================================
# Apply Ruleset
# ==================================================================================================

set -euo pipefail

repo="${1:?Usage: bash scripts/apply-ruleset.sh OWNER/REPO}"
config="$(dirname "${BASH_SOURCE[0]}")/../.github/rulesets/main.json"
endpoint="repos/$repo/rulesets"
method=POST
id=$(
  gh api "$endpoint" \
    --paginate \
    --jq '.[] | select(.name == "main") | .id'
)

if [[ -n "$id" ]]; then
  endpoint+="/$id"
  method=PUT
fi

gh api "$endpoint" \
  --method "$method" \
  --input "$config"
