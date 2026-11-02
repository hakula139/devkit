[.[].jobs[]] as $jobs
| first($jobs[] | select(.id == $gate))
  // error("job \($gate) is missing from this run attempt")
| $jobs[]
| select(.status == "completed")
| select(.conclusion != "success" and .conclusion != "skipped")
| "::error::\(.name): \(.conclusion // .status)"
