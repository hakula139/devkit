#!/usr/bin/env bash
set -euo pipefail

case "$1" in
alpha)
if true; then
printf '%s\n' alpha |
cat
fi
;;
esac
