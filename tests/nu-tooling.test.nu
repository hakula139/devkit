use std/assert

def "test gives each test an empty TMPDIR" [] {
  assert (ls $env.TMPDIR | is-empty)
}

def "test reports nu-check errors" [] {
  let file = ($env.TMPDIR | path join "broken.nu")
  "def greet [] {" | save $file

  let result = (^nu-check $file | complete)

  assert equal $result.exit_code 1
  assert str contains $result.stderr $"($file):1:"
}

def "test rejects arguments that Nushell would parse as code" [] {
  let marker = ($env.TMPDIR | path join "marker")
  let cases = [
    [name args];
    ["flag splice" ["file.nu" $"--help;^touch ($marker)"]]
    ["redirection" ["file.nu" "o>" $marker]]
    ["spread" ["...$env.PATH"]]
  ]

  for case in $cases {
    let result = (^nu-check ...$case.args | complete)

    assert equal $result.exit_code 1 $case.name
    assert str contains $result.stderr "would parse this argument as code" $case.name
    assert not ($marker | path exists) $case.name
  }
}

def "test passes a flag value with Nushell syntax through as a string" [] {
  let marker = ($env.TMPDIR | path join "marker")

  let result = (^nu-check $"--help=x;^touch ($marker)" | complete)

  assert not ($result.stderr | str contains "would parse this argument as code")
  assert not ($marker | path exists)
}

# `checks.nu-tooling` expects this failure, which shows that the runner reports one.
def "test fails on purpose" [] {
  assert false
}
