# Print the arguments and wrapper environment as NUON.
def --wrapped main [
  ...rest: string # Arguments to print, including undeclared options
  --baked # Passed by the wrapper's flags
  --config: path # JSON configuration to print
  --count: int # Count to print
  --mode: string # Mode to print
] {
  print (
    {
      baked: $baked
      config: (open $config)
      count: $count
      environment: $env.DEVKIT_ECHO_ARGS_TEST_VALUE
      mode: $mode
      rest: $rest
    }
    | to nuon
  )
}
