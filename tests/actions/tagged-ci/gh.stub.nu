#!/usr/bin/env nu

# ==================================================================================================
# gh Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  $"($args | to json --raw)\n" | save --append $env.STUB_GH_LOG

  let responses_dir = $env.STUB_GH_RESPONSES_DIR
  let counter_file = ($env.TMPDIR | path join "gh-call-count")
  let count = if ($counter_file | path exists) {
    (open --raw $counter_file | str trim | into int) + 1
  } else {
    1
  }
  $"($count)" | save --force $counter_file

  let response_file = ($responses_dir | path join $"($count).json")
  if not ($response_file | path exists) {
    print -e $"gh stub: no response file for call ($count)"
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
