use std/assert

def "test passes wrapper flags to main after the script" [] {
  let result = (^echo-args "a" | complete)

  assert equal $result.exit_code 0
  assert equal $result.stderr ""
  assert equal ($result.stdout | from nuon) {
    baked: true
    config: {
      service: {
        endpoint: "https://example.com/api"
        retries: 2
      }
    }
    count: 3
    environment: "wrapper"
    mode: "fast mode"
    rest: ["--label" "first" "--tag" "one" "--tag" "two value" "--raw" "a"]
    source: "echo-args.nu"
  }
}

def "test combines wrapper args with caller options and typed values" [] {
  $env.DEVKIT_ECHO_ARGS_TEST_VALUE = "caller"

  let result = (
    ^echo-args "alpha" "beta value"
      --count 5
      --mode "caller"
    | complete
  )

  assert equal $result.exit_code 0
  assert equal $result.stderr ""
  assert equal ($result.stdout | from nuon) {
    baked: true
    config: {
      service: {
        endpoint: "https://example.com/api"
        retries: 2
      }
    }
    count: 5
    environment: "wrapper"
    mode: "caller"
    rest: ["--label" "first" "--tag" "one" "--tag" "two value" "--raw" "alpha" "beta value"]
    source: "echo-args.nu"
  }
}

def "test passes a flag value with Nushell syntax through as a string" [] {
  let marker = ($env.TMPDIR | path join "marker")
  let value = $"x;^touch ($marker)"

  let result = (^echo-args $"--mode=($value)" | complete)

  assert equal $result.exit_code 0
  assert equal ($result.stdout | from nuon | get mode) $value
  assert equal $result.stderr ""
  assert not ($marker | path exists)
}

def "test rejects arguments that Nushell would parse as code" [] {
  let marker = ($env.TMPDIR | path join "marker")
  let cases = [
    [name args];
    ["flag splice" ["file.nu" $"--help;^touch ($marker)"]]
    ["redirection" ["file.nu" "o>" $marker]]
    ["spread" ["...$env.PATH"]]
  ]

  for case in $cases {
    let result = (^nu-check ...$case.args | complete)

    assert equal $result.exit_code 1 $case.name
    assert str contains $result.stderr "would parse this argument as code" $case.name
    assert not ($marker | path exists) $case.name
  }
}
