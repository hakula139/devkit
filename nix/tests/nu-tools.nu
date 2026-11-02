#!/usr/bin/env nu

# ==================================================================================================
# Nushell Tool Check
# ==================================================================================================
# Runs `nu-test` and `nu-check` on the fixtures from their parent directory, as `nuTests` runs
# files from the `src` root, so `nu-test` must find each stub beside its test file.
# ==================================================================================================

use std/assert

const FIXTURES = path self fixtures

# Check the `nu-test` and `nu-check` on `PATH` against the fixtures.
def main [] {
  let cases = [
    {
      name: "passing tests exit 0"
      tool: nu-test
      args: [nu-tools/stubs.test.nu]
      exit_code: 0
      stdout: [
        "PASS nu-tools/stubs.test.nu: test a stub runs with or without a shebang"
        "PASS nu-tools/stubs.test.nu: test the scratch directory holds only the stubs"
        "2 passed, 0 failed"
      ]
      stderr: []
    }
    {
      name: "a test that removes its scratch directory or locks a directory in it still reports"
      tool: nu-test
      args: [nu-tools/removes-scratch.test.nu nu-tools/locked.test.nu]
      exit_code: 0
      stdout: [
        "PASS nu-tools/removes-scratch.test.nu: test removes its scratch directory"
        "PASS nu-tools/locked.test.nu: test leaves a locked directory behind"
        "2 passed, 0 failed"
      ]
      stderr: []
    }
    {
      name: "a failing test fails the run"
      tool: nu-test
      args: [nu-tools/fails.test.nu]
      exit_code: 1
      stdout: ["PASS nu-tools/fails.test.nu: test passes" "1 passed, 1 failed"]
    }
    {
      name: "each load failure counts"
      tool: nu-test
      args: [nu-tools/broken.test.nu nu-tools/noisy.test.nu]
      exit_code: 1
      stdout: ["0 passed, 2 failed"]
    }
    {
      name: "a missing file fails to load"
      tool: nu-test
      args: [nu-tools/missing.test.nu]
      exit_code: 1
      stdout: ["0 passed, 1 failed"]
      stderr: ["FAIL nu-tools/missing.test.nu: (load)" "File not found"]
    }
    {
      name: "a run without tests fails and says why"
      tool: nu-test
      args: []
      exit_code: 1
      stdout: ["0 passed, 0 failed"]
      stderr: ['No "test <behavior>" commands found in the given files.']
    }
    {
      name: "every file is checked, and an error names its line and column"
      tool: nu-check
      args: [nu-tools/stubs.test.nu nu-tools/positions.nu nu-tools/shebang.stub.nu]
      exit_code: 1
      stdout: []
      stderr: [
        "nu-tools/positions.nu:2:15: Extra positional argument."
        "nu-tools/positions.nu:3:1: Variable not found."
      ]
    }
    {
      name: "an error at a file's end still names its line and column, and each error in a loaded module is reported once"
      tool: nu-check
      args: [nu-tools/broken.test.nu nu-tools/uses-broken.nu]
      exit_code: 1
      stdout: []
      stderr: [
        "nu-tools/broken.test.nu:1:23: Unclosed delimiter."
        "nu-tools/broken.test.nu:2:1: Unclosed delimiter."
        "nu-tools/uses-broken.nu: Expected keyword. (in a module it loads)"
        "nu-tools/uses-broken.nu: Unclosed delimiter. (in a module it loads)"
      ]
    }
    {
      name: "a file that is not UTF-8 fails the check"
      tool: nu-check
      args: [nu-tools/invalid-utf8.nu]
      exit_code: 1
      stdout: []
      stderr: ["nu-tools/invalid-utf8.nu: Non-UTF8 string"]
    }
  ]

  cd $FIXTURES
  $env.TMPDIR = (mktemp --directory)
  for case in $cases {
    let result = (^$case.tool ...$case.args | complete)

    # A case without `stderr` leaves it unchecked, since Nushell's diagnostics name absolute paths.
    let expected = ($case | reject name tool args)
    let actual = (
      {
        exit_code: $result.exit_code
        stdout: ($result.stdout | lines)
        stderr: ($result.stderr | lines)
      }
      | select ...($expected | columns)
    )
    assert equal $actual $expected $case.name
  }

  assert equal (ls $env.TMPDIR) [] "nu-test leaves no scratch directory behind"
  rm $env.TMPDIR
}
