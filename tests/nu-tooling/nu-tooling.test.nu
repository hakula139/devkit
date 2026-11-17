use std/assert
use std-rfc/str

def "test passes wrapper flags to main after the script" [] {
  let result = (^echo-args "a" | complete)

  assert equal $result.exit_code 0
  assert equal $result.stderr ""
  assert equal ($result.stdout | from nuon) {
    baked: true
    config: {
      service: {
        endpoint: "https://example.com/api"
        retries: 2
      }
    }
    count: 3
    environment: "wrapper"
    mode: "fast mode"
    rest: ["--label" "first" "--tag" "one" "--tag" "two value" "--raw" "a"]
    source: "echo-args.nu"
  }
}

def "test combines wrapper args with caller options and typed values" [] {
  $env.DEVKIT_ECHO_ARGS_TEST_VALUE = "caller"

  let result = (
    ^echo-args "alpha" "beta value"
      --count 5
      --mode "caller"
    | complete
  )

  assert equal $result.exit_code 0
  assert equal $result.stderr ""
  assert equal ($result.stdout | from nuon) {
    baked: true
    config: {
      service: {
        endpoint: "https://example.com/api"
        retries: 2
      }
    }
    count: 5
    environment: "wrapper"
    mode: "caller"
    rest: ["--label" "first" "--tag" "one" "--tag" "two value" "--raw" "alpha" "beta value"]
    source: "echo-args.nu"
  }
}

def "test passes a flag value with Nushell syntax through as a string" [] {
  let marker = ($env.TMPDIR | path join "marker")
  let value = $"x;^touch ($marker)"

  let result = (^echo-args $"--mode=($value)" | complete)

  assert equal $result.exit_code 0
  assert equal ($result.stdout | from nuon | get mode) $value
  assert equal $result.stderr ""
  assert not ($marker | path exists)
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

def "test packages multi-file application with clean help name and skills" [] {
  let app_root = (which echo-app | first | get path | path dirname | path dirname)

  let help = (^echo-app --help | complete)
  let result = (^echo-app "world" | complete)

  assert equal $help.exit_code 0
  assert equal $help.stderr ""
  assert str contains $help.stdout "> echo-app"
  assert not ($help.stdout | str contains "echo-app.nu")
  assert equal $result.exit_code 0
  assert equal $result.stderr ""
  assert equal ($result.stdout | from nuon) {
    mode: "app mode"
    target: "world"
  }
  assert (($app_root | path join "share/skills/skill/SKILL.md") | path exists)
  assert not (($app_root | path join "share/echo-app/ignored.testlib.nu") | path exists)
}

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

def "test gives each test an empty TMPDIR" [] {
  let dir = $env.TMPDIR

  let result = (ls --all $dir)

  assert equal $result []
}

def "test installs dotted stubs and skips directories" [] {
  let dir = ($env.TMPDIR | path join "suite")
  mkdir ($dir | path join "ignored.stub.nu")
  ^ln -s ($dir | path join "ignored.stub.nu") ($dir | path join "ignored-link.stub.nu")
  (
    '
    #!/usr/bin/env nu
    print "dotted-ok"
    '
    | str dedent
    | save ($dir | path join "foo.bar.stub.nu")
  )
  let file = ($dir | path join "dotted.test.nu")
  (
    '
    use std/assert
    def "test runs dotted stub" [] {
      let file = ($env.NU_TEST_STUBS | path join "foo.bar")

      let result = (^$file | complete)

      assert equal $result {
        exit_code: 0
        stdout: "dotted-ok\n"
        stderr: ""
      }
    }
    '
    | str dedent
    | save $file
  )

  let result = (^nu-test $file | complete)

  assert equal $result {
    exit_code: 0
    stdout: $"PASS ($file): test runs dotted stub\n1 passed, 0 failed\n"
    stderr: ""
  }
}

def "test rejects malformed whitespace in test names" [] {
  let file = ($env.TMPDIR | path join "whitespace.test.nu")
  (
    '
    use std/assert
    def "test  double" [] { assert false }
    def "test trailing " [] { assert false }
    '
    | str dedent
    | save $file
  )

  let result = (^nu-test $file | complete)

  assert equal $result.exit_code 1
  assert str contains $result.stderr $"FAIL ($file): \(load\)"
  assert str contains $result.stderr "test  double:"
  assert str contains $result.stderr "test trailing :"
  assert str contains $result.stdout "0 passed, 2 failed"
}

def "test fails load and cleans scratch on non-UTF-8 stub" [] {
  let scratch_root = ($env.TMPDIR | path join "scratch-root")
  let dir = ($env.TMPDIR | path join "bad-stub")
  mkdir $scratch_root $dir
  0x[41 ff 0a] | save ($dir | path join "broken.stub.nu")
  let file = ($dir | path join "stub-error.test.nu")
  'def "test body" [] {}' | save $file

  let result = (with-env {TMPDIR: $scratch_root} { ^nu-test $file | complete })

  assert equal $result.exit_code 1
  assert str contains $result.stderr $"FAIL ($file): \(load\)"
  assert str contains $result.stderr "Non-UTF8 string"
  assert (ls --all $scratch_root | is-empty)
}

# `checks.nu-tooling` expects this failure, which shows that the runner reports one.
def "test fails on purpose" [] {
  assert false
}
