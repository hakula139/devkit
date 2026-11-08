# Pull request runs test a merge commit, so only push and dispatched runs count.
[.[].workflow_runs[] | select(.event == "push" or .event == "workflow_dispatch")]
| first(.[] | select(.conclusion == "success") | "passed \(.html_url)")
  // if any(.[]; .status != "completed") then "running" else "failed" end
