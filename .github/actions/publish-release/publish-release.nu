#!/usr/bin/env nu

# ==================================================================================================
# Publish Release
# ==================================================================================================

# Publish the tag's `CHANGELOG.md` section as its GitHub Release.
def main [] {
  let tag = $env.GITHUB_REF_NAME
  let version = ($tag | str replace --regex '^v' "")
  let notes = (^parse-changelog "CHANGELOG.md" $version)

  let prerelease = if ($tag | str contains "-") {
    ["--prerelease"]
  } else {
    []
  }

  let assets = (
    $env.ASSETS?
    | default ""
    | lines
    | where {|line| $line | is-not-empty }
    | each {|pattern|
      let matches = (try { glob $pattern } catch { [] })
      if ($matches | is-empty) {
        [$pattern]
      } else {
        $matches | sort
      }
    }
    | flatten
  )

  (
    ^gh release create $tag
      --verify-tag
      --title $tag
      --notes $notes
      ...$prerelease
      ...$assets
  )
}
