#!/usr/bin/env nu

# ==================================================================================================
# Nushell Test Runner
# ==================================================================================================
# Each `test <behavior>` in a `.test.nu` file runs in its own `nu` process.
# ==================================================================================================

def nu-run [file: string, body: string]: nothing -> record {
  ^$nu.current-exe --no-config-file --commands $"source ($file | to nuon)\n($body)" | complete
}

# Install each `<name>.stub.nu` beside `file` in `dir` as an executable `<name>`, whose shebang
# names this interpreter by its store path, since the build sandbox has no `/usr/bin/env`.
def install-stubs [file: string, dir: string]: nothing -> nothing {
  mkdir $dir
  let source = ($file | path expand | path dirname)
  for stub in (ls $source | where name ends-with ".stub.nu" | get name) {
    let target = ($dir | path join ($stub | path basename | str replace ".stub.nu" ""))
    let script = (open --raw $stub | str replace --regex '^#!.*\n?' "")
    $"#!($nu.current-exe) --no-config-file\n($script)" | save $target
    ^chmod +x $target
  }
}

def load-failure [file: string, run: record]: nothing -> record {
  {file: $file, name: "(load)", run: ($run | upsert exit_code 1)}
}

# The outcome of every test in `file`, or a single failure when the file does not load.
def run-file [file: string]: nothing -> list<record> {
  let path = ($file | path expand)
  let found = (nu-run $path "scope commands | where name starts-with 'test ' | get name | to json")
  let names = (try { $found.stdout | from json } catch { null })
  if $found.exit_code != 0 or $names == null {
    return [(load-failure $file $found)]
  }

  $names | each {|name| {file: $file, name: $name, run: (nu-run $path $name)} }
}

# Run each `test <behavior>` command in the given files, exiting nonzero if any fails or none run.
def main [
  ...files: string # `.test.nu` files to run
] {
  let results = (
    $files
    | each {|file|
      if not ($file | path exists) {
        return [(load-failure $file {stdout: "File not found", stderr: ""})]
      }

      let scratch = (mktemp --directory)
      let stubs = ($scratch | path join stubs)
      let outcomes = (try {
        install-stubs $file $stubs
        with-env {TMPDIR: $scratch, NU_TEST_STUBS: $stubs} { run-file $file }
      } catch {|err|
        [(load-failure $file {stdout: $err.msg, stderr: ""})]
      })

      # A test may remove its scratch directory or leave a store copy in it that `rm` cannot empty.
      if ($scratch | path exists) {
        ^chmod -R u+rwx $scratch
        rm --recursive $scratch
      }

      $outcomes
    }
    | flatten
  )

  for result in $results {
    if $result.run.exit_code == 0 {
      print $"PASS ($result.file): ($result.name)"
    } else {
      print -e $"FAIL ($result.file): ($result.name)\n($result.run.stdout)($result.run.stderr)"
    }
  }

  let failed = ($results | where run.exit_code != 0 | length)
  let passed = ($results | length) - $failed
  print $"($passed) passed, ($failed) failed"
  if ($results | is-empty) {
    print -e 'No "test <behavior>" commands found in the given files.'
    exit 1
  }

  if $failed > 0 {
    exit 1
  }
}
