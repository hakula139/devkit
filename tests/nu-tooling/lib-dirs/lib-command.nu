use shout.nu
use whisper.nu

def main [text: string] {
  print $"(shout upper $text) (whisper lower $text)"
}
