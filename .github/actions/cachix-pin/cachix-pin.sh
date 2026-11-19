#!/usr/bin/env bash

# ==================================================================================================
# Pin Cachix Store Paths
# ==================================================================================================

set -euo pipefail

jq -r 'to_entries[] | [.key, .value] | @tsv' <<<"$PINS" \
  | while IFS=$'\t' read -r name installable; do
    store_path=$(nix build "$installable" --no-link --print-out-paths --print-build-logs)
    cachix push hakula "$store_path"
    cachix pin hakula "$name" "$store_path" --keep-revisions "$KEEP_REVISIONS"
  done
