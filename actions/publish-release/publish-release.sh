#!/usr/bin/env bash

# ==================================================================================================
# Publish Release
# ==================================================================================================

set -euo pipefail

notes=$(parse-changelog CHANGELOG.md "${GITHUB_REF_NAME#v}")

options=(
  --verify-tag
  --title "$GITHUB_REF_NAME"
  --notes "$notes"
)
if [[ "$GITHUB_REF_NAME" == *-* ]]; then
  options+=(--prerelease)
fi

IFS=$'\n'
# shellcheck disable=SC2206 # Split on newlines, and let gh reject a pattern that matches nothing.
options+=($ASSETS)

gh release create "$GITHUB_REF_NAME" "${options[@]}"
