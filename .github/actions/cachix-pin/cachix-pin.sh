#!/usr/bin/env bash

# ==================================================================================================
# Pin Cachix Store Paths
# ==================================================================================================

set -euo pipefail

if [[ -n "${KEEP_DAYS:-}" ]]; then
  if [[ -n "${KEEP_REVISIONS:-}" ]]; then
    printf '%s\n' 'Specify only one of keep-days and keep-revisions.' >&2
    exit 1
  fi

  retention=(--keep-days "$KEEP_DAYS")
else
  retention=(--keep-revisions "${KEEP_REVISIONS:-2}")
fi

jq -r 'to_entries[] | [.key, .value] | @tsv' <<<"$PINS" \
  | while IFS=$'\t' read -r name installable; do
    store_path=$(nix build "$installable" --no-link --print-out-paths --print-build-logs)
    cachix push hakula "$store_path"
    cachix pin hakula "$name" "$store_path" "${retention[@]}"
  done
