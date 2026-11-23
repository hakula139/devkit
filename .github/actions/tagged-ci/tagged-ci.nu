#!/usr/bin/env nu

# ==================================================================================================
# Tagged CI
# ==================================================================================================

# Wait for a push or dispatched `ci.yml` run to pass on the tagged commit.
def main [] {
  let poll_interval = (
    $env.TAGGED_CI_POLL_INTERVAL?
    | default "30sec"
    | into duration
  )
  let endpoint = $"repos/($env.GITHUB_REPOSITORY)/actions/workflows/ci.yml/runs"

  loop {
    let api = (
      ^gh api $endpoint
        --method GET
        --raw-field $"head_sha=($env.GITHUB_SHA)"
        --raw-field "per_page=100"
        --paginate
        --slurp
      | complete
    )
    if $api.exit_code != 0 {
      if ($api.stderr | is-not-empty) {
        print -e --no-newline $api.stderr
      }
      print "::error::Could not read the runs of .github/workflows/ci.yml, which tagged-ci waits for."
      exit 1
    }

    let pages = try {
      $api.stdout | from json
    } catch {
      print "::error::Could not read the runs of .github/workflows/ci.yml, which tagged-ci waits for."
      exit 1
    }

    # Pull request runs test a merge commit, so only push and dispatched runs count.
    let runs = (
      $pages
      | each {|page| $page.workflow_runs }
      | flatten
      | where event in ["push" "workflow_dispatch"]
    )

    let passed = (
      $runs
      | where conclusion == "success"
      | first
    )
    if $passed != null {
      print $"CI passed on ($env.GITHUB_SHA): ($passed.html_url)"
      exit 0
    }

    if ($runs | any {|run| $run.status != "completed" }) {
      sleep $poll_interval
    } else {
      [
        $"::error::No push or dispatched CI run passed on ($env.GITHUB_SHA)."
        "Rerun the failed CI jobs,"
        $"or run 'gh workflow run ci.yml --ref ($env.GITHUB_REF_NAME)',"
        "then rerun this job."
      ]
      | str join " "
      | print $in
      exit 1
    }
  }
}
