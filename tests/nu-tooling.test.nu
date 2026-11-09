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

# `checks.nu-tooling` expects this failure, which shows that the runner reports one.
def "test fails on purpose" [] {
  assert false
}
