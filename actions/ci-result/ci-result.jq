[.[].jobs[]] as $jobs
# Jobs of a calling workflow share this run, so check only names with this prefix.
| (first($jobs[] | select(.id == $gate) | .name | sub("[^/]*$"; ""))
  // error("job \($gate) is missing from this run attempt")) as $prefix
| $jobs[]
| select(.status == "completed" and .conclusion != "success" and .conclusion != "skipped")
| select(.name | startswith($prefix))
| "::error::\(.name): \(.conclusion)"
