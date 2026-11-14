#!/usr/bin/env bash

# ==================================================================================================
# Release Actions Tests
# ==================================================================================================

set -euo pipefail

publisher=$1
work=$(mktemp -d)
trap 'rm -r "$work"' EXIT
cd "$work"

export GITHUB_REF_NAME=v1.2.3 ASSETS=""
export GH_ARGS="$work/gh-args" PARSER_LOG="$work/parser-log" PARSER_STATUS=0

gh() {
  printf '%s\n' "$@" >"$GH_ARGS"
}

parse-changelog() {
  printf '%s\n' "$@" >"$PARSER_LOG"
  [[ -f "$1" && "$2" == "1.2.3" ]]
  if [[ "$PARSER_STATUS" != "0" ]]; then
    return "$PARSER_STATUS"
  fi
  printf '%s\n' 'Release notes from the selected section.'
}

export -f gh parse-changelog

printf '%s\n' '# Changelog' >CHANGELOG.md

NOTES_SOURCE=changelog bash "$publisher"

grep -Fxq -- '--notes' "$GH_ARGS"
grep -Fxq -- 'Release notes from the selected section.' "$GH_ARGS"
grep -Fxq -- 'CHANGELOG.md' "$PARSER_LOG"

rm "$GH_ARGS"
export PARSER_STATUS=1

if NOTES_SOURCE=changelog bash "$publisher"; then
  echo 'Changelog parsing failure did not stop publication.' >&2
  exit 1
fi

[[ ! -e "$GH_ARGS" ]]
echo 'PASS changelog notes and parser failure'

rm CHANGELOG.md "$PARSER_LOG"

NOTES_SOURCE=tag bash "$publisher"

grep -Fxq -- '--notes-from-tag' "$GH_ARGS"
[[ ! -e "$PARSER_LOG" ]]
echo 'PASS tag notes without a changelog parser'
