use std/assert

def "test a stub runs with or without a shebang" [] {
  for stub in [shebang no-shebang] {
    assert equal (^($env.NU_TEST_STUBS | path join $stub) Ada) "hello, Ada" $stub
  }
}

def "test the scratch directory holds only the stubs" [] {
  assert equal (ls $env.TMPDIR | get name | path basename) [stubs]
}
