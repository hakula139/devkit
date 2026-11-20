use std/assert

const TEST_DIR = path self "."

def "test resolves library directories by module name" [] {
  let cases = [
    [command expected];
    [lib-command "HI hi\n"]
    [lib-app "HI\n"]
  ]

  for case in $cases {
    let result = (^$case.command "Hi" | complete)

    assert equal $result.exit_code 0 $case.command
    assert equal $result.stderr "" $case.command
    assert equal $result.stdout $case.expected $case.command
  }
}

def "test finds modules through the test check library directories" [] {
  use shout.nu
  use whisper.nu

  assert equal [(shout upper "Ok") (whisper lower "Ok")] [OK ok]
}

def "test checks scripts that use library modules" [] {
  let file = ($TEST_DIR | path join "fixtures/uses-lib.nu")

  # Nushell exports `NU_LIB_DIRS` to an external command only as a string.
  let result = (
    with-env {NU_LIB_DIRS: ($env.NU_LIB_DIRS | str join (char esep))} {
      ^nu-check $file | complete
    }
  )

  assert equal $result.exit_code 0 $result.stderr
  assert equal $result.stderr ""
}
