#!/usr/bin/env nu

# ==================================================================================================
# Pin Cachix Store Paths
# ==================================================================================================

def main [] {
  let keep_days = ($env.KEEP_DAYS? | default "")
  let keep_revisions = ($env.KEEP_REVISIONS? | default "")

  let retention = if ($keep_days | is-not-empty) {
    if ($keep_revisions | is-not-empty) {
      print -e "Specify only one of keep-days and keep-revisions."
      exit 1
    }

    [--keep-days $keep_days]
  } else if ($keep_revisions | is-not-empty) {
    [--keep-revisions $keep_revisions]
  } else {
    [--keep-revisions "2"]
  }

  let pins = (
    $env.PINS
    | from json
    | transpose name installable
  )

  for pin in $pins {
    let store_path = (
      ^nix build $pin.installable
        --no-link
        --print-out-paths
        --print-build-logs
      | str trim
    )
    ^cachix push "hakula" $store_path
    ^cachix pin "hakula" $pin.name $store_path ...$retention
  }
}
