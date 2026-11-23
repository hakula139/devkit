use std/assert

const SCRIPT = path self "../../scripts/cachix-pin.nu"

def run-cachix-pin [
  pins: record
  --keep-revisions: string = ""
  --keep-days: string = ""
] {
  let log = ($env.TMPDIR | path join "calls.log")
  let path = ($env.PATH | prepend $env.NU_TEST_STUBS)

  let result = (
    with-env {
      PATH: $path
      CACHIX_PIN_TEST_LOG: $log
      PINS: ($pins | to json)
      KEEP_REVISIONS: $keep_revisions
      KEEP_DAYS: $keep_days
    } {
      if ($SCRIPT | path exists) {
        ^$nu.current-exe $SCRIPT | complete
      } else {
        ^cachix-pin | complete
      }
    }
  )
  let calls = if ($log | path exists) {
    open --raw $log | lines
  } else {
    []
  }

  {
    result: $result
    calls: $calls
  }
}

def "test defaults to two kept revisions" [] {
  let out = (run-cachix-pin {app-main: ".#default"})

  assert equal $out.result.exit_code 0 $out.result.stderr
  assert equal $out.result.stderr ""
  assert equal $out.calls [
    "nix build .#default --no-link --print-out-paths --print-build-logs"
    "cachix push hakula /nix/store/stub-default"
    "cachix pin hakula app-main /nix/store/stub-default --keep-revisions 2"
  ]
}

def "test passes explicit keep-revisions" [] {
  let out = (run-cachix-pin {app-main: ".#default"} --keep-revisions "5")

  assert equal $out.result.exit_code 0 $out.result.stderr
  assert equal $out.result.stderr ""
  assert equal $out.calls [
    "nix build .#default --no-link --print-out-paths --print-build-logs"
    "cachix push hakula /nix/store/stub-default"
    "cachix pin hakula app-main /nix/store/stub-default --keep-revisions 5"
  ]
}

def "test passes keep-days" [] {
  let out = (run-cachix-pin {app-v1: ".#default.out"} --keep-days "30")

  assert equal $out.result.exit_code 0 $out.result.stderr
  assert equal $out.result.stderr ""
  assert equal $out.calls [
    "nix build .#default.out --no-link --print-out-paths --print-build-logs"
    "cachix push hakula /nix/store/stub-default-out"
    "cachix pin hakula app-v1 /nix/store/stub-default-out --keep-days 30"
  ]
}

def "test pins multiple entries" [] {
  let out = (
    run-cachix-pin {
      first: ".#a"
      second: ".#b"
    }
  )

  assert equal $out.result.exit_code 0 $out.result.stderr
  assert equal $out.calls [
    "nix build .#a --no-link --print-out-paths --print-build-logs"
    "cachix push hakula /nix/store/stub-a"
    "cachix pin hakula first /nix/store/stub-a --keep-revisions 2"
    "nix build .#b --no-link --print-out-paths --print-build-logs"
    "cachix push hakula /nix/store/stub-b"
    "cachix pin hakula second /nix/store/stub-b --keep-revisions 2"
  ]
}

def "test rejects keep-days and keep-revisions together" [] {
  let out = (
    run-cachix-pin {app-v1: ".#default"}
      --keep-days "30"
      --keep-revisions "2"
  )

  assert equal $out.result.exit_code 1
  assert equal $out.result.stdout ""
  assert equal $out.result.stderr "Specify only one of keep-days and keep-revisions.\n"
  assert equal $out.calls []
}
