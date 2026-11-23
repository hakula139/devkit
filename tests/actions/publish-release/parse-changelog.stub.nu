def --wrapped main [...args: string] {
  $"($args | to json --raw)\n" | save --append $env.STUB_PARSE_CHANGELOG_LOG

  let exit_code = ($env.STUB_PARSE_CHANGELOG_EXIT? | default "0" | into int)
  if $exit_code != 0 {
    print -e ($env.STUB_PARSE_CHANGELOG_STDERR? | default "parse-changelog failed")
    exit $exit_code
  }

  print --no-newline ($env.STUB_PARSE_CHANGELOG_NOTES? | default "")
}
