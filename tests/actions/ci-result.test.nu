use std/assert

const SCRIPT = path self "../../.github/actions/ci-result/ci-result.nu"

def run-ci-result [
  pages: list<record>
  --gate-id: string = "100"
  --exit-code: int = 0
  --stderr: string = ""
] {
  let responses_dir = ($env.TMPDIR | path join "responses")
  mkdir $responses_dir
  {
    exit_code: $exit_code
    stdout: ($pages | to json)
    stderr: $stderr
  }
  | to json
  | save ($responses_dir | path join "default.json")

  let log = ($env.TMPDIR | path join "gh.jsonl")
  let path = ($env.PATH | prepend $env.NU_TEST_STUBS)

  let result = (
    with-env {
      PATH: $path
      STUB_GH_LOG: $log
      STUB_GH_RESPONSES_DIR: $responses_dir
      GITHUB_REPOSITORY: "hakulab/example"
      GITHUB_RUN_ID: "42"
      GATE_ID: $gate_id
    } {
      if ($SCRIPT | path exists) {
        ^$nu.current-exe $SCRIPT | complete
      } else {
        ^ci-result | complete
      }
    }
  )
  let calls = if ($log | path exists) {
    open --raw $log
    | lines
    | each {|line| $line | from json }
  } else {
    []
  }

  {
    result: $result
    calls: $calls
  }
}

def "test passes when all completed jobs succeeded or were skipped" [] {
  let out = (
    run-ci-result [
      {
        jobs: [
          {id: 1, name: "Nix Check (ubuntu-latest)", run_attempt: 1, status: "completed", conclusion: "success"}
          {id: 2, name: "macOS Check", run_attempt: 1, status: "completed", conclusion: "skipped"}
          {id: 100, name: "CI Result", run_attempt: 1, status: "in_progress", conclusion: null}
        ]
      }
    ]
  )

  assert equal $out.result {
    exit_code: 0
    stdout: ""
    stderr: ""
  }
  assert equal $out.calls [
    [
      "api"
      "repos/hakulab/example/actions/runs/42/jobs"
      "--method"
      "GET"
      "--raw-field"
      "filter=all"
      "--raw-field"
      "per_page=100"
      "--paginate"
      "--slurp"
    ]
  ]
}

def "test fails with error annotations for failed or cancelled jobs" [] {
  let out = (
    run-ci-result [
      {
        jobs: [
          {id: 1, name: "Build", run_attempt: 1, status: "completed", conclusion: "failure"}
          {id: 2, name: "Matrix (macos)", run_attempt: 1, status: "completed", conclusion: "cancelled"}
          {id: 100, name: "CI Result", run_attempt: 1, status: "in_progress", conclusion: null}
        ]
      }
    ]
  )

  assert equal $out.result.exit_code 1
  assert equal $out.result.stderr ""
  assert equal ($out.result.stdout | lines | sort) [
    "::error::Build: failure"
    "::error::Matrix (macos): cancelled"
  ]
}

def "test uses the latest run attempt per job name across pages" [] {
  let out = (
    run-ci-result [
      {
        jobs: [
          {id: 1, name: "Build", run_attempt: 1, status: "completed", conclusion: "failure"}
          {id: 100, name: "CI Result", run_attempt: 2, status: "in_progress", conclusion: null}
        ]
      }
      {
        jobs: [
          {id: 2, name: "Build", run_attempt: 2, status: "completed", conclusion: "success"}
        ]
      }
    ]
  )

  assert equal $out.result {
    exit_code: 0
    stdout: ""
    stderr: ""
  }
}

def "test ignores jobs outside the gate workflow prefix" [] {
  let out = (
    run-ci-result [
      {
        jobs: [
          {id: 1, name: "other / Lint", run_attempt: 1, status: "completed", conclusion: "failure"}
          {id: 2, name: "sub / Test", run_attempt: 1, status: "completed", conclusion: "success"}
          {id: 100, name: "sub / CI Result", run_attempt: 1, status: "in_progress", conclusion: null}
        ]
      }
    ]
  )

  assert equal $out.result {
    exit_code: 0
    stdout: ""
    stderr: ""
  }
}

def "test fails when a job with the gate workflow prefix failed" [] {
  let out = (
    run-ci-result [
      {
        jobs: [
          {id: 1, name: "other / Lint", run_attempt: 1, status: "completed", conclusion: "failure"}
          {id: 2, name: "sub / Test", run_attempt: 1, status: "completed", conclusion: "failure"}
          {id: 100, name: "sub / CI Result", run_attempt: 1, status: "in_progress", conclusion: null}
        ]
      }
    ]
  )

  assert equal $out.result {
    exit_code: 1
    stdout: "::error::sub / Test: failure\n"
    stderr: ""
  }
}

def "test errors when the gate job is missing from the workflow run" [] {
  let out = (
    run-ci-result [
      {
        jobs: [
          {id: 1, name: "Build", run_attempt: 1, status: "completed", conclusion: "success"}
        ]
      }
    ] --gate-id "999"
  )

  assert equal $out.result {
    exit_code: 1
    stdout: ""
    stderr: "job 999 is missing from this workflow run\n"
  }
}
