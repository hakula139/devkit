use std/assert

const SCRIPT = path self "../../.github/actions/publish-release/publish-release.nu"

def run-publish-release [
  --tag: string = "v1.2.3"
  --notes: string = "Added feature X."
  --assets: string = ""
  --cwd: string = ""
  --changelog-exit: int = 0
] {
  let work_dir = if ($cwd | is-empty) {
    $env.TMPDIR
  } else {
    $cwd
  }
  let gh_log = ($env.TMPDIR | path join "gh.jsonl")
  let changelog_log = ($env.TMPDIR | path join "parse-changelog.jsonl")
  let path = ($env.PATH | prepend $env.NU_TEST_STUBS)

  let result = (
    with-env {
      PATH: $path
      STUB_GH_LOG: $gh_log
      STUB_PARSE_CHANGELOG_LOG: $changelog_log
      STUB_PARSE_CHANGELOG_NOTES: $notes
      STUB_PARSE_CHANGELOG_EXIT: $"($changelog_exit)"
      GITHUB_REF_NAME: $tag
      ASSETS: $assets
    } {
      do {
        cd $work_dir
        if ($SCRIPT | path exists) {
          ^$nu.current-exe $SCRIPT | complete
        } else {
          ^publish-release | complete
        }
      }
    }
  )

  let gh_calls = if ($gh_log | path exists) {
    open --raw $gh_log
    | lines
    | each {|line| $line | from json }
  } else {
    []
  }
  let changelog_calls = if ($changelog_log | path exists) {
    open --raw $changelog_log
    | lines
    | each {|line| $line | from json }
  } else {
    []
  }

  {
    result: $result
    gh_calls: $gh_calls
    changelog_calls: $changelog_calls
  }
}

def "test publishes a stable release without assets" [] {
  let out = (
    run-publish-release
      --tag "v1.2.3"
      --notes "Release notes for 1.2.3"
  )

  assert equal $out.result {
    exit_code: 0
    stdout: ""
    stderr: ""
  }
  assert equal $out.changelog_calls [
    ["CHANGELOG.md" "1.2.3"]
  ]
  assert equal $out.gh_calls [
    [
      "release"
      "create"
      "v1.2.3"
      "--verify-tag"
      "--title"
      "v1.2.3"
      "--notes"
      "Release notes for 1.2.3"
    ]
  ]
}

def "test marks hyphenated tags as prereleases" [] {
  let out = (
    run-publish-release
      --tag "v1.2.3-rc.1"
      --notes "RC notes"
  )

  assert equal $out.result.exit_code 0 $out.result.stderr
  assert equal $out.changelog_calls [
    ["CHANGELOG.md" "1.2.3-rc.1"]
  ]
  assert equal $out.gh_calls [
    [
      "release"
      "create"
      "v1.2.3-rc.1"
      "--verify-tag"
      "--title"
      "v1.2.3-rc.1"
      "--notes"
      "RC notes"
      "--prerelease"
    ]
  ]
}

def "test expands newline-separated asset globs and keeps unmatched patterns" [] {
  let repo = ($env.TMPDIR | path join "repo")
  let dist = ($repo | path join "dist")
  mkdir $dist
  "a" | save ($dist | path join "app-linux.tar.gz")
  "b" | save ($dist | path join "app-macos.tar.gz")

  let assets = "dist/*.tar.gz\n\nmissing/*.zip\n"
  let out = (
    run-publish-release
      --tag "v2.0.0"
      --notes "Notes"
      --assets $assets
      --cwd $repo
  )

  assert equal $out.result.exit_code 0 $out.result.stderr
  assert equal $out.gh_calls [
    [
      "release"
      "create"
      "v2.0.0"
      "--verify-tag"
      "--title"
      "v2.0.0"
      "--notes"
      "Notes"
      ($dist | path join "app-linux.tar.gz")
      ($dist | path join "app-macos.tar.gz")
      "missing/*.zip"
    ]
  ]
}

def "test stops before calling gh when parse-changelog fails" [] {
  let out = (
    run-publish-release
      --tag "v1.2.3"
      --changelog-exit 1
  )

  assert equal $out.result.exit_code 1
  assert str contains $out.result.stderr "parse-changelog failed"
  assert equal $out.gh_calls []
}
