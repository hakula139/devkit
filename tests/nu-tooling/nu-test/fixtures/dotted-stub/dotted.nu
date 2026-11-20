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
