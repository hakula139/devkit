#!/usr/bin/env bash

# ==================================================================================================
# Publish Release
# ==================================================================================================

set -euo pipefail

options=(
  --verify-tag
  --title "$GITHUB_REF_NAME"
)
case "$NOTES_SOURCE" in
  changelog)
    notes=$(parse-changelog CHANGELOG.md "${GITHUB_REF_NAME#v}")
    options+=(--notes "$notes")
    ;;
  tag)
    options+=(--notes-from-tag)
    ;;
  *)
    echo "::error::Unknown release notes source '$NOTES_SOURCE'. Use 'changelog' or 'tag'."
    exit 1
    ;;
esac

if [[ "$GITHUB_REF_NAME" == *-* ]]; then
  options+=(--prerelease)
fi

IFS=$'\n'
# shellcheck disable=SC2206 # Split on newlines, and let gh reject a pattern that matches nothing.
options+=($ASSETS)

gh release create "$GITHUB_REF_NAME" "${options[@]}"
