# ==================================================================================================
# CI Result API Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  if $args == [
    "api"
    "repos/example/project/actions/runs/100/jobs?filter=all&per_page=100"
    "--paginate"
    "--slurp"
  ] {
    print $env.CI_RESULT_ALL
  } else {
    error make {msg: $"Unexpected GitHub request: ($args | to nuon)"}
  }
}
