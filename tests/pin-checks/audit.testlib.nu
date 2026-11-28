use pin-check.nu

def registry []: nothing -> list<record> {
  let sample = {
    pin: "sample"
    local: {|| "1.0"}
    upstream: {|| "2.0"}
  }
  let pins = match $env.PIN_CASE {
    "list" => [
      {
        pin: "sample"
        local: {|| error make {msg: "local lookup ran"} }
        upstream: {|| error make {msg: "upstream lookup ran"} }
      }
    ]
    "current" => [
      ($sample | merge {
        classify: {|pinned, upstream|
          {
            status: $"tracks channel ($pinned) to ($upstream)"
            outcome: "current"
          }
        }
      })
    ]
    "stale" => [
      ($sample | merge {
        classify: {|_pinned, _upstream|
          {
            status: "pin superseded"
            outcome: "stale"
          }
        }
      })
    ]
    "mixed" => [
      $sample
      {
        pin: "failed"
        local: {|| "1.0"}
        upstream: {|| error make {msg: "upstream unavailable"} }
      }
      {
        pin: "missing"
        local: {||
          print -e "  cannot read missing version"
          null
        }
        upstream: {|| "2.0"}
      }
    ]
    "blank" => [
      ($sample | merge {upstream: {|| ""}})
    ]
    "github" => [
      ($sample | merge {upstream: {|| pin-check gh-latest-release "example/sample"}})
    ]
    "empty" => []
  }
  [
    {
      title: "Packages"
      pins: $pins
    }
  ]
}

def "main list" [--footer: string] {
  pin-check list {|| registry } --footer $footer
}

def "main root" [] {
  pin-check repo-root "example"
}

def main [] {
  pin-check check {|| registry }
}
