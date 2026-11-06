#!/usr/bin/env nu

# ==================================================================================================
# Nushell Diagnostic Check
# ==================================================================================================
# Wraps `nu --ide-check`, which reports diagnostics as JSON on stdout and exits 0 despite errors.
# ==================================================================================================

const MAX_ERRORS = 100

# The 1-based `line:column` of the byte `offset` in `text`, counting bytes as Nushell does.
def position [text: string, offset: int]: nothing -> string {
  let lines = ($text | str substring ..<$offset | split row "\n")
  $"($lines | length):(($lines | last | str length) + 1)"
}

def diagnostics [target: string, text: string]: nothing -> list<string> {
  let result = (^$nu.current-exe --ide-check $MAX_ERRORS $target | complete)
  if $result.exit_code != 0 {
    error make {msg: $"nu --ide-check failed for ($target): ($result.stderr)"}
  }

  # A loaded module's spans start where `text` ends, so a span that ends past it is the module's.
  let size = ($text | str length)
  $result.stdout
  | from json --objects
  | where severity? == "Error"
  | each {|d|
    if $d.span.end <= $size {
      $"($target):(position $text $d.span.start): ($d.message)"
    } else {
      $"($target): ($d.message) \(in a module it loads\)"
    }
  }
  | uniq
}

# The errors in `file`, or the reason it cannot be read.
def check [file: string]: nothing -> list<string> {
  # `--ide-check` passes invalid UTF-8 in a comment.
  let text = (
    try {
      open --raw $file | into string
    } catch {|err|
      return [$"($file): ($err.msg)"]
    }
  )
  diagnostics $file $text
}

# Check the given Nushell files, exiting nonzero if any is missing, is not UTF-8, or has an error.
def main [
  ...files: string # Nushell files to check
] {
  let errors = ($files | each {|file| check $file } | flatten)
  for error in $errors { print -e $error }
  if ($errors | is-not-empty) {
    exit 1
  }
}
