use std/assert

const SCRIPT = path self "audit.testlib.nu"

def "test list is offline and leaves row closures lazy" [] {
  let lib_dirs = ($env.NU_LIB_DIRS | str join (char esep))
  let results = (with-env {NU_LIB_DIRS: $lib_dirs, PIN_CASE: "list", PATH: []} {
    [
      (^$nu.current-exe --no-config-file $SCRIPT list | complete)
      (^$nu.current-exe --no-config-file $SCRIPT list --footer "See the project guide." | complete)
    ]
  })

  let listing = "Manual pins tracked by this script:\n\nPackages\n  sample\n"
  assert equal $results [
    {
      stdout: $listing
      stderr: ""
      exit_code: 0
    }
    {
      stdout: ($listing + "\nSee the project guide.\n")
      stderr: ""
      exit_code: 0
    }
  ]
}

def "test check derives exit code from outcomes and diagnoses incomplete groups" [] {
  let lib_dirs = ($env.NU_LIB_DIRS | str join (char esep))
  let cases = [
    [name code summary label warnings];
    ["current" 0 "0 stale, 0 unknown." "tracks channel 1.0 to 2.0" []]
    ["stale" 1 "1 stale, 0 unknown." "pin superseded" []]
    ["mixed" 2 "1 stale, 2 unknown." "UNKNOWN" ["  cannot read missing version" "  failed: upstream unavailable"]]
    ["blank" 2 "0 stale, 1 unknown." "UNKNOWN" ["  sample: no value found"]]
    ["github" 2 "0 stale, 1 unknown." "UNKNOWN" ["  sample: gh: Service unavailable (HTTP 503)"]]
    ["empty" 2 "0 stale, 1 unknown." "UNKNOWN" ["  Packages: no pins matched"]]
  ]

  for case in $cases {
    let result = (with-env {
      NU_LIB_DIRS: $lib_dirs
      PIN_CASE: $case.name
      PATH: [$env.NU_TEST_STUBS]
    } {
      ^$nu.current-exe --no-config-file $SCRIPT | complete
    })

    assert equal $result.exit_code $case.code $case.name
    assert ($result.stdout | str contains $case.summary) $case.name
    let table = ($result.stdout | split row $case.summary | first)
    assert ($table | str contains $case.label) $case.name
    assert (not ($table | str contains "outcome")) $case.name
    assert equal ($result.stderr | lines | sort) $case.warnings $case.name
  }
}

def "test repo-root reports the expected checkout when Git fails" [] {
  let lib_dirs = ($env.NU_LIB_DIRS | str join (char esep))
  let result = (with-env {NU_LIB_DIRS: $lib_dirs, PATH: [$env.NU_TEST_STUBS]} {
    ^$nu.current-exe --no-config-file $SCRIPT root | complete
  })

  assert equal $result {
    stdout: ""
    stderr: "error: cannot find the repository root. Run inside the example checkout.\n"
    exit_code: 2
  }
}
