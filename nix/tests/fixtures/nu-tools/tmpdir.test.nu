def "test the first scratch directory" [] {
  print $"TMPDIR=($env.TMPDIR)"
  exit 1
}

def "test the second scratch directory" [] {
  print $"TMPDIR=($env.TMPDIR)"
  exit 1
}
