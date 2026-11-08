#!/usr/bin/env nu

# ==================================================================================================
# GitHub Administration
# ==================================================================================================

# Show the repository administration commands.
def main [] {
  help main
}

# Create or replace the main branch ruleset.
def "main ruleset" [
  repo: string # Target repository as OWNER/REPO
  --config: path # Complete ruleset JSON, defaulting to the shared main ruleset
] {
  let source = if $config == null {
    $env.FILE_PWD | path join "../.github/rulesets/main.json"
  } else {
    $config
  }

  mut endpoint = $"repos/($repo)/rulesets"
  let id = (
    ^gh api $endpoint
      --paginate
      --jq '.[] | select(.name == "main") | .id'
    | str trim
  )

  mut method = "POST"
  if $id != "" {
    $endpoint = $"($endpoint)/($id)"
    $method = "PUT"
  }

  (
    ^gh api $endpoint
      --method $method
      --input $source
  )
}

# Apply repository settings and workflow token permissions.
def "main settings" [
  repo: string # Target repository as OWNER/REPO
] {
  let settings = ($env.FILE_PWD | path join "../.github/repository-settings.json")
  let permissions = ($env.FILE_PWD | path join "../.github/workflow-permissions.json")

  (
    ^gh api $"repos/($repo)"
      --method PATCH
      --input $settings
  )

  (
    ^gh api $"repos/($repo)/actions/permissions/workflow"
      --method PUT
      --input $permissions
  )
}

# Make published releases immutable.
def "main immutable-releases" [
  repo: string # Target repository as OWNER/REPO
] {
  ^gh api $"repos/($repo)/immutable-releases" --method PUT
}

# Apply the repository security defaults.
def "main security" [
  repo: string # Target repository as OWNER/REPO
] {
  let settings = ($env.FILE_PWD | path join "../.github/security-settings.json")

  ^gh api $"repos/($repo)/vulnerability-alerts" --method PUT

  ^gh api $"repos/($repo)/automated-security-fixes" --method DELETE

  ^gh api $"repos/($repo)/private-vulnerability-reporting" --method PUT

  (
    ^gh api $"repos/($repo)"
      --method PATCH
      --input $settings
  )
}

# Create or update the shared labels.
def "main labels" [
  repo: string # Target repository as OWNER/REPO
  ...areas: string # Optional component names without the area: prefix
] {
  let shared = (open ($env.FILE_PWD | path join "../.github/labels.json"))
  let components = (
    $areas
    | each {|area|
      {
        name: $"area: ($area)"
        color: "bfd4f2"
        description: $"Changes to ($area)"
      }
    }
  )
  let labels = ($shared | append $components)

  for label in $labels {
    (
      ^gh label create $label.name
        --repo $repo
        --color $label.color
        --description $label.description
        --force
    )
  }
}

# Refresh a release's notes from CHANGELOG.md in the current directory.
def "main release-notes" [
  repo: string # Target repository as OWNER/REPO
  tag: string # Release tag, such as v1.2.3
] {
  let version = ($tag | str replace --regex '^v' "")
  let notes = (^parse-changelog "CHANGELOG.md" $version)

  (
    ^gh release edit $tag
      --repo $repo
      --notes $notes
  )
}
