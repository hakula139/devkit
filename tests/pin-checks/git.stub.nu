def main [command: string, --show-toplevel] {
  if $command != "rev-parse" or not $show_toplevel {
    print -e "unexpected git arguments"
  }
  exit 128
}
