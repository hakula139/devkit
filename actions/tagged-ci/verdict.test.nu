#!/usr/bin/env nu

# ==================================================================================================
# Tagged CI Verdict Tests
# ==================================================================================================

use std/assert

const FILTER_FILE = path self "verdict.jq"

def verdict [runs: table]: nothing -> record {
  (
    [{workflow_runs: $runs}]
    | to json
    | ^jq
      -r
      -f $FILTER_FILE
    | complete
  )
}

def "test the verdict" [] {
  let cases = [
    {
      name: "a passed push run releases"
      runs: [
        [event status conclusion html_url];
        ["push" "completed" "success" "https://example.com/1"]
      ]
      expected: "passed https://example.com/1"
    }
    {
      name: "a dispatch after a failed push releases"
      runs: [
        [event status conclusion html_url];
        ["push" "completed" "failure" null]
        ["workflow_dispatch" "completed" "success" "https://example.com/2"]
      ]
      expected: "passed https://example.com/2"
    }
    {
      name: "a queued push run waits"
      runs: [
        [event status conclusion html_url];
        ["push" "queued" null null]
      ]
      expected: "running"
    }
    {
      name: "a passed pull request run alone fails"
      runs: [
        [event status conclusion html_url];
        ["pull_request" "completed" "success" null]
      ]
      expected: "failed"
    }
    {
      name: "a passed pull request run beside a failed push run fails"
      runs: [
        [event status conclusion html_url];
        ["pull_request" "completed" "success" null]
        ["push" "completed" "failure" null]
      ]
      expected: "failed"
    }
  ]

  for case in $cases {
    let result = (verdict $case.runs)
    assert equal $result.exit_code 0 $"($case.name): ($result.stderr)"

    assert equal ($result.stdout | str trim) $case.expected $case.name
  }
}
