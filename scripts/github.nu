#!/usr/bin/env nu

# ==================================================================================================
# GitHub Administration
# ==================================================================================================

const SCRIPT_DIR = path self "."

# Show the repository administration commands.
def main [] {
  help main
}

# Apply repository and workflow settings, security defaults, and immutable releases.
def "main settings" [
  repo: string # Target repository as OWNER/REPO
] {
  let repository_settings = ($SCRIPT_DIR | path join "../.github/settings/repository.json")
  let workflow_permissions = ($SCRIPT_DIR | path join "../.github/settings/workflow-permissions.json")
  let security_settings = ($SCRIPT_DIR | path join "../.github/settings/security.json")

  (
    ^gh api $"repos/($repo)"
      --method PATCH
      --input $repository_settings
  )
  (
    ^gh api $"repos/($repo)/actions/permissions/workflow"
      --method PUT
      --input $workflow_permissions
  )
  ^gh api $"repos/($repo)/vulnerability-alerts" --method PUT
  ^gh api $"repos/($repo)/automated-security-fixes" --method DELETE
  ^gh api $"repos/($repo)/private-vulnerability-reporting" --method PUT
  (
    ^gh api $"repos/($repo)"
      --method PATCH
      --input $security_settings
  )
  ^gh api $"repos/($repo)/immutable-releases" --method PUT
}

# Create or replace the main branch ruleset.
def "main ruleset" [
  repo: string # Target repository as OWNER/REPO
  --config: path # Complete ruleset JSON, defaulting to the shared main ruleset
] {
  let main_ruleset = ($SCRIPT_DIR | path join "../.github/settings/rulesets/main.json")
  let source = if $config == null {
    $main_ruleset
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

# Create or update the shared labels.
def "main labels" [
  repo: string # Target repository as OWNER/REPO
  ...areas: string # Optional component names without the area: prefix
] {
  let labels_config = ($SCRIPT_DIR | path join "../.github/settings/labels.json")
  let shared = (open $labels_config)
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
