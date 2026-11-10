# shellcheck shell=bash

# Nushell runs a script's `main` by splicing the arguments into source text, and it leaves the
# flag name of an argument starting with `--` unquoted, so `--help;cmd` would run `cmd`.
for arg in "$@"; do
  if [[ "$arg" == --* && ! "$arg" =~ ^--([A-Za-z][A-Za-z0-9-]*(=.*)?)?$ ]]; then
    echo "${0##*/}: an argument starting with -- must be --name or --name=value: $arg" >&2
    exit 1
  fi
done
