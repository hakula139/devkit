#!/usr/bin/env nu

# ==================================================================================================
# Changelog Draft
# ==================================================================================================

const SHARED_CONFIG = path self "../cliff.toml"

# Prepend a release draft to CHANGELOG.md from the target repository root.
def main [
  tag: string # Release tag, such as v1.2.3 or v1.2.3-rc.1
  --highlights: path # Markdown highlights file for templates that support it
] {
  let repo = (
    ^gh repo view
      --json nameWithOwner
      --jq .nameWithOwner
    | str trim
  )
  let config = if ("cliff.toml" | path exists) {
    "cliff.toml"
  } else {
    $SHARED_CONFIG
  }
  let tag_args = if ($tag | str contains "-") {
    ["--tag-pattern" '^v[0-9]']
  } else {
    []
  }
  let highlights_args = if $highlights == null {
    []
  } else {
    [$"--with-tag-message=(open --raw $highlights)"]
  }

  (
    ^nix run "nixpkgs#git-cliff" --
      --offline
      --github-repo $repo
      --config $config
      --unreleased
      --tag $tag
      ...$tag_args
      ...$highlights_args
      --prepend "CHANGELOG.md"
  )
}
