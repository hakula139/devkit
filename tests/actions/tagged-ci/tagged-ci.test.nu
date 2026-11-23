use std/assert

const SCRIPT = path self "../../../.github/actions/tagged-ci/tagged-ci.nu"

def run-tagged-ci [
  responses: list<record>
  --sha: string = "abc1234"
  --ref-name: string = "v1.2.3"
] {
  let responses_dir = ($env.TMPDIR | path join "responses")
  mkdir $responses_dir
  for entry in ($responses | enumerate) {
    let index = $entry.index + 1
    $entry.item
    | to json
    | save ($responses_dir | path join $"($index).json")
  }

  let log = ($env.TMPDIR | path join "gh.jsonl")
  let path = ($env.PATH | prepend $env.NU_TEST_STUBS)

  let result = (
    with-env {
      PATH: $path
      STUB_GH_LOG: $log
      STUB_GH_RESPONSES_DIR: $responses_dir
      GITHUB_REPOSITORY: "hakulab/example"
      GITHUB_SHA: $sha
      GITHUB_REF_NAME: $ref_name
      TAGGED_CI_POLL_INTERVAL: "10ms"
    } {
      if ($SCRIPT | path exists) {
        ^$nu.current-exe $SCRIPT | complete
      } else {
        ^tagged-ci | complete
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

def "test succeeds when a push run passed" [] {
  let pages = [
    {
      workflow_runs: [
        {
          event: "push"
          status: "completed"
          conclusion: "success"
          html_url: "https://github.com/hakulab/example/actions/runs/10"
        }
      ]
    }
  ]
  let out = (
    run-tagged-ci [
      {exit_code: 0, stdout: ($pages | to json)}
    ]
  )

  assert equal $out.result {
    exit_code: 0
    stdout: "CI passed on abc1234: https://github.com/hakulab/example/actions/runs/10\n"
    stderr: ""
  }
  assert equal $out.calls [
    [
      "api"
      "repos/hakulab/example/actions/workflows/ci.yml/runs"
      "--method"
      "GET"
      "--raw-field"
      "head_sha=abc1234"
      "--raw-field"
      "per_page=100"
      "--paginate"
      "--slurp"
    ]
  ]
}

def "test polls while a dispatched run is in progress then succeeds" [] {
  let running = [
    {
      workflow_runs: [
        {
          event: "workflow_dispatch"
          status: "in_progress"
          conclusion: null
          html_url: "https://github.com/hakulab/example/actions/runs/20"
        }
      ]
    }
  ]
  let passed = [
    {
      workflow_runs: [
        {
          event: "workflow_dispatch"
          status: "completed"
          conclusion: "success"
          html_url: "https://github.com/hakulab/example/actions/runs/20"
        }
      ]
    }
  ]
  let out = (
    run-tagged-ci [
      {exit_code: 0, stdout: ($running | to json)}
      {exit_code: 0, stdout: ($passed | to json)}
    ]
  )

  assert equal $out.result {
    exit_code: 0
    stdout: "CI passed on abc1234: https://github.com/hakulab/example/actions/runs/20\n"
    stderr: ""
  }
  assert equal ($out.calls | length) 2
}

def "test ignores pull request runs and fails when no qualifying run passed" [] {
  let pages = [
    {
      workflow_runs: [
        {
          event: "pull_request"
          status: "completed"
          conclusion: "success"
          html_url: "https://github.com/hakulab/example/actions/runs/30"
        }
        {
          event: "push"
          status: "completed"
          conclusion: "failure"
          html_url: "https://github.com/hakulab/example/actions/runs/31"
        }
      ]
    }
  ]
  let out = (
    run-tagged-ci [
      {exit_code: 0, stdout: ($pages | to json)}
    ]
  )

  assert equal $out.result {
    exit_code: 1
    stdout: (
      "::error::No push or dispatched CI run passed on abc1234."
      + " Rerun the failed CI jobs,"
      + " or run 'gh workflow run ci.yml --ref v1.2.3',"
      + " then rerun this job.\n"
    )
    stderr: ""
  }
}

def "test reports an error when gh api fails" [] {
  let out = (
    run-tagged-ci [
      {exit_code: 1, stdout: "", stderr: "HTTP 404\n"}
    ]
  )

  assert equal $out.result {
    exit_code: 1
    stdout: (
      "::error::Could not read the runs of .github/workflows/ci.yml,"
      + " which tagged-ci waits for.\n"
    )
    stderr: "HTTP 404\n"
  }
}
