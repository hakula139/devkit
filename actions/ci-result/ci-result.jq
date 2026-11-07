[.[].jobs[]]
| group_by(.name)
| map(max_by(.run_attempt)) as $jobs
# Jobs of a calling workflow share this run, so check only names with this prefix.
| (first($jobs[] | select(.id == $gate) | .name | sub("[^/]*$"; ""))
  // error("job \($gate) is missing from this workflow run")) as $prefix
| $jobs[]
| select(.status == "completed" and .conclusion != "success" and .conclusion != "skipped")
| select(.name | startswith($prefix))
| "::error::\(.name): \(.conclusion)"
