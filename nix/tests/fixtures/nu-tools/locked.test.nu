def "test leaves a locked directory behind" [] {
  let dir = ($env.TMPDIR | path join locked)
  mkdir $dir
  touch ($dir | path join file)
  ^chmod 000 $dir
}
