def --wrapped main [...args: string] {
  $"($args | to json --raw)\n" | save --append $env.STUB_GH_LOG

  let response_file = ($env.STUB_GH_RESPONSES_DIR | path join "default.json")
  if not ($response_file | path exists) {
    print -e "gh stub: missing default.json response file"
    exit 1
  }

  let response = (open $response_file)
  if ($response.stderr? | default "" | is-not-empty) {
    print -e --no-newline $response.stderr
  }
  if ($response.stdout? | default "" | is-not-empty) {
    print --no-newline $response.stdout
  }
  let code = ($response.exit_code? | default 0)
  if $code != 0 {
    exit $code
  }
}
