#!/usr/bin/env nu

# ==================================================================================================
# CI Result Filter Tests
# ==================================================================================================

use std/assert

const FILTER_FILE = path self "ci-result.jq"
const SCRIPT_FILE = path self "ci-result.sh"

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
        [id name status conclusion run_attempt];
        [1 "Other / cancelled" "completed" "cancelled" 1]
        [2 "CI / gate" "in_progress" null 1]
        [3 "CI / build" "completed" "success" 1]
        [4 "CI / skipped-leg" "completed" "skipped" 1]
        [5 "CI / cancelled-leg" "completed" "cancelled" 1]
        [6 "CI / running-leg" "in_progress" null 1]
      ]
      expected: ["::error::CI / cancelled-leg: cancelled"]
    }
    {
      name: "a top-level gate reports a failed job of a called workflow"
      gate: 1
      jobs: [
        [id name status conclusion run_attempt];
        [1 "CI Result" "in_progress" null 1]
        [2 "nix / Nix (Linux)" "completed" "failure" 1]
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
  assert str contains $result.stderr "job 1 is missing from this workflow run"
}

def "test reruns retain the latest result of each upstream job" [] {
  let cases = [
    {
      name: "a gate-only rerun retains an earlier failure"
      earlier: "failure"
      rerun: null
      exit_code: 1
    }
    {
      name: "a passing rerun supersedes an earlier failure"
      earlier: "failure"
      rerun: "success"
      exit_code: 0
    }
    {
      name: "a failing rerun supersedes an earlier success"
      earlier: "success"
      rerun: "failure"
      exit_code: 1
    }
  ]

  for case in $cases {
    let prior = [
      {id: 1, name: "CI / build", status: "completed", conclusion: $case.earlier, run_attempt: 1}
      {id: 2, name: "CI / gate", status: "completed", conclusion: "failure", run_attempt: 1}
    ]
    let current = (
      [{id: 3, name: "CI / gate", status: "in_progress", conclusion: null, run_attempt: 2}]
      | append (if $case.rerun == null {
        []
      } else {
        [{id: 4, name: "CI / build", status: "completed", conclusion: $case.rerun, run_attempt: 2}]
      })
    )
    let all = (
      [{jobs: $current} {jobs: $prior}]
      | to json
    )
    let attempt = (
      [{jobs: $current}]
      | to json
    )

    let result = with-env {
      PATH: ($env.PATH | prepend $env.NU_TEST_STUBS)
      CI_RESULT_ALL: $all
      CI_RESULT_ATTEMPT: $attempt
      GITHUB_REPOSITORY: "example/project"
      GITHUB_RUN_ID: "100"
      GITHUB_RUN_ATTEMPT: "2"
      GITHUB_ACTION_PATH: ($SCRIPT_FILE | path dirname)
      GATE_ID: "3"
    } {
      ^bash $SCRIPT_FILE
      | complete
    }
    assert equal $result.exit_code $case.exit_code $"($case.name): ($result.stderr)"

    let expected = if $case.exit_code == 0 {
      []
    } else {
      ["::error::CI / build: failure"]
    }
    assert equal ($result.stdout | lines) $expected $"($case.name): ($result.stderr)"
  }
}
