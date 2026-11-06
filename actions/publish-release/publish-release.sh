#!/usr/bin/env bash

# ==================================================================================================
# Publish Release
# ==================================================================================================

set -euo pipefail

notes="$RUNNER_TEMP/release-notes.md"
parse-changelog CHANGELOG.md "${GITHUB_REF_NAME#v}" >"$notes"

options=(
  --verify-tag
  --title "$GITHUB_REF_NAME"
  --notes-file "$notes"
)
if [[ "$GITHUB_REF_NAME" == *-* ]]; then
  options+=(--prerelease)
fi

IFS=$'\n'
# shellcheck disable=SC2206 # Split on newlines, and let gh reject a pattern that matches nothing.
options+=($ASSETS)

gh release create "$GITHUB_REF_NAME" "${options[@]}"
