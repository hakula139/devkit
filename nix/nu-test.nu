#!/usr/bin/env nu

# ==================================================================================================
# Nushell Test Runner
# ==================================================================================================
# A test is a command named `test <behavior>` in a `.test.nu` file. Each runs in its own `nu`
# process with its own `TMPDIR`, so a test that changes its environment or exits cannot affect the
# others. Each `<name>.stub.nu` beside a test file is installed as `<name>` in `NU_TEST_STUBS`.
# ==================================================================================================

def nu-run [file: string, body: string, tmp: string, stubs: string]: nothing -> record {
  with-env {TMPDIR: $tmp, NU_TEST_STUBS: $stubs} {
    (
      ^$nu.current-exe
        --no-config-file
        --commands $"source ($file | to nuon)\n($body)"
      | complete
    )
  }
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

# Create the scratch directory and stubs for `file`, then return them with one job per test, or
# one job carrying the load failure when the file does not load.
def plan-file [file: string]: nothing -> record {
  let path = ($file | path expand)
  let scratch = (mktemp --directory)
  let stubs = ($scratch | path join "stubs")
  install-stubs $file $stubs
  let query = "scope commands | where name starts-with 'test ' | get name | to json"
  let found = (nu-run $path $query $scratch $stubs)
  let jobs = if $found.exit_code != 0 {
    [(load-failure $file $found)]
  } else {
    try {
      $found.stdout
      | from json
      | each {|name|
        if ($name =~ '^test [A-Za-z0-9 ,.:-]+$') {
          {file: $file, name: $name, path: $path, scratch: $scratch, stubs: $stubs}
        } else {
          let message = "A test name may hold only letters, digits, spaces, and `,.:-`."
          {file: $file, name: $name, run: {exit_code: 1, stdout: "", stderr: $message}}
        }
      }
    } catch {
      [(load-failure $file $found)]
    }
  }

  {scratch: $scratch, jobs: $jobs}
}

# Run `job` in a fresh `TMPDIR` under its file's scratch, or return any discovery failure.
def run-job [job: record]: nothing -> record {
  if ($job.run? != null) {
    return $job
  }

  let tmp = (mktemp --directory --tmpdir-path $job.scratch)
  {file: $job.file, name: $job.name, run: (nu-run $job.path $job.name $tmp $job.stubs)}
}

# Run every test in the given files, exiting nonzero if any fails or none run.
def main [
  ...files: string # `.test.nu` files to run
] {
  # Nested `par-each` builds a private thread pool per inner call, so plan every test first and
  # run the flat job list on one default-size pool.
  let plans = ($files | par-each --keep-order {|file| plan-file $file })
  let results = (
    $plans
    | get jobs
    | flatten
    | par-each --keep-order {|job| run-job $job }
  )

  # A test may leave a read-only directory in its file's scratch, which `rm` cannot empty.
  for plan in $plans {
    ^chmod -R u+rwx $plan.scratch
    rm --recursive $plan.scratch
  }

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
