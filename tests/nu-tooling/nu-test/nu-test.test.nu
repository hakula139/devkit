use std/assert

const TEST_DIR = path self "."

def "test gives each test an empty TMPDIR" [] {
  let dir = $env.TMPDIR

  let result = (ls --all $dir)

  assert equal $result []
}

def "test installs dotted stubs and skips directories" [] {
  let fixtures = ($TEST_DIR | path join "fixtures/dotted-stub")
  let dir = ($env.TMPDIR | path join "suite")
  mkdir ($dir | path join "ignored.stub.nu")
  ^ln -s ($dir | path join "ignored.stub.nu") ($dir | path join "ignored-link.stub.nu")
  ^cp ($fixtures | path join "foo.bar.stub.nu") ($dir | path join "foo.bar.stub.nu")
  let file = ($dir | path join "dotted.test.nu")
  ^cp ($fixtures | path join "dotted.nu") $file

  let result = (^nu-test $file | complete)

  assert equal $result {
    exit_code: 0
    stdout: $"PASS ($file): test runs dotted stub\n1 passed, 0 failed\n"
    stderr: ""
  }
}

def "test rejects malformed whitespace in test names" [] {
  let file = ($env.TMPDIR | path join "whitespace.test.nu")
  ^cp ($TEST_DIR | path join "fixtures/whitespace-names/whitespace.nu") $file

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

# `checks.nu-tooling-nu-test` expects this failure, which shows that the runner reports one.
def "test fails on purpose" [] {
  assert false
}
