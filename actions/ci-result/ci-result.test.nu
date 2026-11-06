#!/usr/bin/env nu

# ==================================================================================================
# CI Result Filter Tests
# ==================================================================================================

use std/assert

const FILTER_FILE = path self "ci-result.jq"

def ci-result [gate: int, jobs: table]: nothing -> record {
  (
    [{jobs: $jobs}]
    | to json
    | ^jq
      -r
      --argjson gate $gate
      -f $FILTER_FILE
    | complete
  )
}

def "test the gate reports each failed job in its workflow" [] {
  let cases = [
    {
      name: "a nested gate reports a cancelled leg of its own workflow only"
      gate: 2
      jobs: [
        [id name status conclusion];
        [1 "Other / cancelled" "completed" "cancelled"]
        [2 "CI / gate" "in_progress" null]
        [3 "CI / build" "completed" "success"]
        [4 "CI / skipped-leg" "completed" "skipped"]
        [5 "CI / cancelled-leg" "completed" "cancelled"]
        [6 "CI / running-leg" "in_progress" null]
      ]
      expected: ["::error::CI / cancelled-leg: cancelled"]
    }
    {
      name: "a top-level gate reports a failed job of a called workflow"
      gate: 1
      jobs: [
        [id name status conclusion];
        [1 "CI Result" "in_progress" null]
        [2 "nix / Nix (Linux)" "completed" "failure"]
      ]
      expected: ["::error::nix / Nix (Linux): failure"]
    }
  ]

  for case in $cases {
    let result = (ci-result $case.gate $case.jobs)
    assert equal $result.exit_code 0 $"($case.name): ($result.stderr)"

    assert equal ($result.stdout | lines) $case.expected $case.name
  }
}

def "test a missing gate is rejected" [] {
  let result = (ci-result 1 [])

  assert not equal $result.exit_code 0
  assert str contains $result.stderr "job 1 is missing from this run attempt"
}
