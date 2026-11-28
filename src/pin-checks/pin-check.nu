# ==================================================================================================
# Pinned Version Checks
# ==================================================================================================

use ./versions.nu newest-version
export use ./versions.nu [version-at-least version-older]

# --------------------------------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------------------------------

# List the groups and pin names without authenticating or running any row closures.
export def list [registry: closure, --footer: string]: nothing -> nothing {
  print "Manual pins tracked by this script:"
  for group in (do $registry) {
    print ""
    print $group.title
    for row in $group.pins {
      print $"  ($row.pin)"
    }
  }
  if ($footer | is-not-empty) {
    print ""
    print $footer
  }
}

def die [msg: string] {
  print -e $"error: ($msg)"
  exit 2
}

# Find the current Git checkout or report the expected checkout and exit 2.
export def repo-root [checkout: string]: nothing -> string {
  try {
    ^git rev-parse --show-toplevel | str trim
  } catch {
    die $"cannot find the repository root. Run inside the ($checkout) checkout."
  }
}

def require-gh [] {
  if (which gh | is-empty) {
    die "gh not found. Install GitHub CLI and authenticate to github.com."
  }
  if (^gh auth status --hostname github.com | complete).exit_code != 0 {
    die "GitHub authentication check failed. Check credentials and network access."
  }
}

def warn [pin: string, message: string] {
  print -e $"($pin): ($message)"
}

def query [pin: string, lookup: closure]: nothing -> string {
  try {
    let raw = (do $lookup)
    if $raw == null {
      return ""
    }
    let value = ($raw | into string | str trim)
    if ($value | is-empty) {
      warn $pin "no value found"
    }
    $value
  } catch {|err|
    warn $pin $err.msg
    ""
  }
}

def classify [row: record, pinned: string, upstream: string]: nothing -> record {
  if ($pinned | is-empty) or ($upstream | is-empty) {
    {
      status: "UNKNOWN"
      outcome: "unknown"
    }
  } else if ($row.classify? | is-not-empty) {
    try {
      let result = (do $row.classify $pinned $upstream)
      if ($result.status | describe) != "string" or $result.outcome not-in [
        "current" "stale" "unknown"
      ] {
        error make {
          msg: "classifier must return a status string and a current, stale, or unknown outcome"
        }
      }
      $result
    } catch {|err|
      warn $row.pin $err.msg
      {
        status: "UNKNOWN"
        outcome: "unknown"
      }
    }
  } else if ($row.delegated? | is-not-empty) {
    {
      status: $row.delegated
      outcome: "current"
    }
  } else if $pinned == $upstream {
    {
      status: "ok"
      outcome: "current"
    }
  } else {
    {
      status: "STALE"
      outcome: "stale"
    }
  }
}

def resolve-row [row: record]: nothing -> record {
  let pinned = (query $row.pin $row.local)
  let upstream = if ($row.delegated? | is-not-empty) {
    $row.delegated
  } else {
    query $row.pin $row.upstream
  }
  let result = (classify $row $pinned $upstream)

  {
    pin: $row.pin
    pinned: ($pinned | default --empty "?")
    upstream: ($upstream | default --empty "?")
    status: $result.status
    outcome: $result.outcome
  }
}

def resolve-group [group: record]: nothing -> record {
  let rows = if ($group.pins | is-empty) {
    warn $group.title "no pins matched"
    [
      {
        pin: $group.title
        pinned: "?"
        upstream: "?"
        status: "UNKNOWN"
        outcome: "unknown"
      }
    ]
  } else {
    $group.pins | par-each --keep-order {|row| resolve-row $row }
  }
  {
    title: $group.title
    rows: $rows
  }
}

# Audit the registry after authenticating. Exit 0 for current, 1 for stale, or 2 for incomplete.
export def check [registry: closure] {
  require-gh

  let groups = (do $registry | par-each --keep-order {|group| resolve-group $group })
  for group in $groups {
    print ""
    print $group.title
    print ($group.rows | reject outcome | table)
  }
  let rows = ($groups | each {|group| $group.rows } | flatten)
  let stale = ($rows | where outcome == "stale" | length)
  let unknown = ($rows | where outcome == "unknown" | length)

  print ""
  print $"($stale) stale, ($unknown) unknown."
  if $unknown > 0 {
    print "UNKNOWN means a lookup failed. Rerun, and fix the printed cause if it persists."
    exit 2
  }
  if $stale > 0 {
    exit 1
  }
}

# --------------------------------------------------------------------------------------------------
# GitHub queries
# --------------------------------------------------------------------------------------------------

def gh-api [path: string, jq: string, --paginate]: nothing -> string {
  let args = if $paginate { ["--paginate"] } else { [] }
  let result = (
    ^gh api $path
      --hostname github.com
      --jq $jq
      ...$args
    | complete
  )
  if $result.exit_code != 0 {
    error make {msg: ($result.stderr | str trim | default --empty "GitHub API request failed")}
  }
  $result.stdout | str trim
}

# Read the tag GitHub marks as the latest release.
export def gh-latest-release [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/releases/latest" ".tag_name"
}

# Read all published releases in GitHub's API order, including pre-releases.
export def gh-releases [repo: string]: nothing -> list<record> {
  let jq = ".[] | select(.draft == false) | @json"
  gh-api $"repos/($repo)/releases?per_page=100" $jq --paginate
  | from json --objects
}

# Read the highest version-shaped release tag, allowing pre-releases.
export def gh-newest-release [repo: string]: nothing -> string {
  newest-version (gh-releases $repo | get tag_name) --allow-pre-release
}

# Resolve the highest stable version tag to its commit, including for annotated tags.
export def gh-newest-tag-head [repo: string]: nothing -> string {
  let tags = (gh-api $"repos/($repo)/tags" ".[].name" --paginate | lines)
  let tag = (newest-version $tags)

  if ($tag | is-empty) {
    error make {msg: "no stable version tag found"}
  }
  gh-api $"repos/($repo)/commits/($tag)" ".sha"
}

# Read the latest commit on the default branch.
export def gh-default-head [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/commits?per_page=1" ".[0].sha"
}

# --------------------------------------------------------------------------------------------------
# Source extraction
# --------------------------------------------------------------------------------------------------

# Extract the first match of the regex's named capture v from a file under root.
export def nix-attr [root: string, file: string, regex: string]: nothing -> string {
  open --raw ($root | path join $file)
  | parse --regex $regex
  | get v.0
}

# Read the first literal version assignment from a Nix file.
export def nix-version [root: string, file: string]: nothing -> string {
  nix-attr $root $file '(?m)^\s*version = "(?<v>[^"]+)"'
}

# --------------------------------------------------------------------------------------------------
# GitHub Actions
# --------------------------------------------------------------------------------------------------

# Read the sorted, unique remote uses refs in workflows and composite actions.
export def action-pins [root: string]: nothing -> list<string> {
  [".github/workflows" ".github/actions"]
  | each {|dir| glob ($root | path join $dir "**/*") }
  | flatten
  | where {|p|
    ($p | path type) == "file" and ($p | path parse | get extension) in ["yml" "yaml"]
  }
  | each {|p|
    let doc = (open $p)
    let jobs = ($doc | get -o jobs | default {} | values)
    [
      ($jobs | get -o uses)
      ($jobs | each {|job| $job | get -o steps | default [] | get -o uses } | flatten)
      ($doc | get -o runs.steps | default [] | get -o uses)
    ]
    | flatten
  }
  | flatten
  | compact
  | where {|pin|
    (
      not ($pin | str starts-with "./")
      and not ($pin | str starts-with "$/")
      and not ($pin | str starts-with "docker://")
    )
  }
  | uniq
  | sort
}

# Turn a GitHub Actions uses ref into a row delegated to Renovate.
export def action-pin [ref: string]: nothing -> record {
  let parts = ($ref | split row "@")
  {
    pin: ($parts | first)
    local: {|| $parts | get 1 }
    delegated: "renovate"
  }
}
