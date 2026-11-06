#!/usr/bin/env nu

# ==================================================================================================
# Tagged CI Filter Tests
# ==================================================================================================

use std/assert

const FILTER_FILE = path self "tagged-ci.jq"

def tagged-ci [runs: table]: nothing -> record {
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
  ]

  for case in $cases {
    let result = (tagged-ci $case.runs)
    assert equal $result.exit_code 0 $"($case.name): ($result.stderr)"

    assert equal ($result.stdout | str trim) $case.expected $case.name
  }
}
