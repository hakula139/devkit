def "test removes its scratch directory" [] {
  rm --recursive $env.TMPDIR
}
