#!/usr/bin/env nu

# ==================================================================================================
# Managed Hook Migration Check
# ==================================================================================================

use std/assert

def main [source: path, shell_hook: path] {
  let scratch = (mktemp --directory)
  let bash = (which bash | first | get path)
  let original = $env.PWD

  try {
    cd $scratch
    cp ($source | path join "flake.nix") .
    ^git init --quiet
    ^git config user.name "Fixture"
    ^git config user.email "fixture@example.com"

    for name in ["pre-commit" "pre-push"] {
      $"#!($bash)\nprintf '%s\\n' ($name) >> custom.log\n"
      | save ($scratch | path join ".git" "hooks" $name)
      ^chmod +x ($scratch | path join ".git" "hooks" $name)
    }

    $"#!($bash)\nprintf '%s\\n' managed >> old.log\n" | save "old-hook.sh"
    ^chmod +x "old-hook.sh"
    {
      repos: [{
        repo: "local"
        hooks: [{
          id: "old-managed-hook"
          name: "Old managed hook"
          entry: ($scratch | path join "old-hook.sh")
          language: "system"
          always_run: true
          pass_filenames: false
          stages: ["pre-commit" "pre-push"]
        }]
      }]
    } | to json | save "old-config.json"
    ^pre-commit install --config old-config.json --hook-type pre-commit --hook-type pre-push

    for iteration in [1 2] {
      let installed = (^bash $shell_hook | complete)
      assert equal $installed.exit_code 0 $installed.stderr

      for name in ["pre-commit" "pre-push"] {
        let args = if $name == "pre-push" { ["--" "fixture" "https://example.com/project.git"] } else { [] }
        let run = (^git hook run $name ...$args | complete)
        assert equal $run.exit_code 0 $"($name), installation ($iteration): ($run.stderr)"
      }

      assert equal (open --raw "custom.log" | lines) (
        1..$iteration | each { ["pre-commit" "pre-push"] } | flatten
      ) $"custom hooks run once after installation ($iteration)"
      assert not ("old.log" | path exists) "the old managed configuration must not execute"
    }
  } finally {
    cd $original
    rm --recursive --force $scratch
  }
}
