use std/assert

def "test checks filenames starting with a dash" [] {
  "def greet [] {}" | save ($env.TMPDIR | path join "-good.nu")
  "def greet [] {" | save ($env.TMPDIR | path join "-bad.nu")

  let result = (do {
    cd $env.TMPDIR
    {
      good: (^nu-check -- "-good.nu" | complete)
      bad: (^nu-check -- "-bad.nu" | complete)
    }
  })

  assert equal $result.good {
    exit_code: 0
    stdout: ""
    stderr: ""
  }
  assert equal $result.bad.exit_code 1
  assert str contains $result.bad.stderr "-bad.nu:1:"
}

def "test reports nu-check errors" [] {
  let file = ($env.TMPDIR | path join "broken.nu")
  "def greet [] {" | save $file

  let result = (^nu-check $file | complete)

  assert equal $result.exit_code 1
  assert str contains $result.stderr $"($file):1:"
}
