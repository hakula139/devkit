# Print the arguments as NUON.
def main [
  ...rest: string
  --baked # Set by the wrapper's makeWrapperArgs.
] {
  print ({baked: $baked rest: $rest} | to nuon)
}
