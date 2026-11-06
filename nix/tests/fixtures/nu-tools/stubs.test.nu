use std/assert

def "test a stub runs with or without a shebang" [] {
  for stub in ["shebang" "no-shebang"] {
    assert equal (^($env.NU_TEST_STUBS | path join $stub) Ada) "hello, Ada" $stub
  }
}

def "test each test starts with an empty scratch directory" [] {
  assert equal (ls $env.TMPDIR) []
}
