use ./helper.nu greeting

# Print the packaged application's greeting and mode as NUON.
def main [
  target: string # Target name to greet
  --mode: string = "default" # Mode passed by wrapper flags or caller
] {
  print (
    greeting $target $mode
    | to nuon
  )
}
