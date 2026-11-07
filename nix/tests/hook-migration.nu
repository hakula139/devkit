#!/usr/bin/env nu

# ==================================================================================================
# Managed Hook Migration Check
# ==================================================================================================

use std/assert

def install-old-hooks [] {
  (
    ^pre-commit install
      --config old-config.json
      --hook-type pre-commit
      --hook-type pre-push
  )
}

def check-migration [source: path, shell_hook: path, custom: bool] {
  let scratch = (mktemp --directory)
  let bash = (
    which bash
    | first
    | get path
  )
  let original = $env.PWD

  try {
    cd $scratch
    cp ($source | path join "flake.nix") .
    ^git init --quiet
    ^git config user.name "Fixture"
    ^git config user.email "fixture@example.com"

    if $custom {
      for name in ["pre-commit" "pre-push"] {
        $"#!($bash)\nprintf '%s\\n' ($name) >> custom.log\n"
        | save ($scratch | path join ".git" "hooks" $name)
        ^chmod +x ($scratch | path join ".git" "hooks" $name)
      }
    }

    $"#!($bash)\nprintf '%s\\n' managed >> old.log\n"
    | save "old-hook.sh"
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
    }
    | to json
    | save "old-config.json"
    install-old-hooks

    for iteration in [1 2 3] {
      if $iteration == 3 {
        let config = (^readlink ".pre-commit-config.yaml")
        if $custom {
          (
            ^prek uninstall
              --hook-type pre-commit
              --hook-type pre-push
          )
        }
        install-old-hooks
        assert equal (^readlink ".pre-commit-config.yaml") $config
      }

      let installed = (
        ^bash $shell_hook
        | complete
      )
      assert equal $installed.exit_code 0 $installed.stderr
      assert (".pre-commit-config.yaml" | path exists) $installed.stderr

      for name in ["pre-commit" "pre-push"] {
        let args = if $name == "pre-push" {
          ["--" "fixture" "https://example.com/project.git"]
        } else {
          []
        }
        let run = (
          ^git hook run $name ...$args
          | complete
        )
        assert equal $run.exit_code 0 $"($name), installation ($iteration): ($run.stderr)"
      }

      if $custom {
        assert equal (
          open --raw "custom.log"
          | lines
        ) (
          1..$iteration
          | each { ["pre-commit" "pre-push"] }
          | flatten
        ) $"custom hooks run once after installation ($iteration)"
      }
      assert ("new.log" | path exists) "the current managed hook must execute"
      assert equal (
        open --raw "new.log"
        | lines
      ) (
        1..($iteration * 2)
        | each { "current" }
      ) $"current managed hooks run once after installation ($iteration)"
      assert not ("old.log" | path exists) "the old managed configuration must not execute"
    }
  } finally {
    cd $original
    rm --recursive --force $scratch
  }
}

def main [source: path, shell_hook: path] {
  for custom in [true false] {
    check-migration $source $shell_hook $custom
  }
}
