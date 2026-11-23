#!/usr/bin/env nu

# ==================================================================================================
# CI Result
# ==================================================================================================

# Fail unless every completed job in the gate's workflow succeeded or was skipped.
def main [] {
  let gate_id = ($env.GATE_ID | into int)
  let endpoint = $"repos/($env.GITHUB_REPOSITORY)/actions/runs/($env.GITHUB_RUN_ID)/jobs"

  # `needs` misses a matrix leg cancelled before it starts, so read each job from the API.
  let pages = (
    ^gh api $endpoint
      --method GET
      --raw-field "filter=all"
      --raw-field "per_page=100"
      --paginate
      --slurp
    | from json
  )
  let jobs = (
    $pages
    | each {|page| $page.jobs }
    | flatten
    | group-by name
    | values
    | each {|group| $group | sort-by run_attempt | last }
  )

  let gate = (
    $jobs
    | where id == $gate_id
    | first
  )
  if $gate == null {
    print -e $"job ($gate_id) is missing from this workflow run"
    exit 1
  }

  # Jobs of a calling workflow share this run, so check only names with this prefix.
  let prefix = ($gate.name | str replace --regex '[^/]*$' "")

  let failed = (
    $jobs
    | where {|job|
      (
        $job.status == "completed"
        and $job.conclusion != "success"
        and $job.conclusion != "skipped"
        and ($job.name | str starts-with $prefix)
      )
    }
    | each {|job| $"::error::($job.name): ($job.conclusion)" }
  )

  if ($failed | is-not-empty) {
    $failed | each {|line| print $line }
    exit 1
  }
}
