#!/usr/bin/env nu

# ==================================================================================================
# GitHub Administration
# ==================================================================================================

const SETTINGS_DIR = path self "../.github/settings"

# Show the repository administration commands.
def main [] {
  help main
}

# Apply repository and workflow settings, security defaults, and immutable releases.
def "main settings" [
  repo: string # Target repository as OWNER/REPO
] {
  let repository_settings = ($SETTINGS_DIR | path join "repository.json")
  let workflow_permissions = ($SETTINGS_DIR | path join "workflow-permissions.json")
  let security_settings = ($SETTINGS_DIR | path join "security.json")

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

# Create or replace the branch ruleset that has the config's name.
def "main ruleset" [
  repo: string # Target repository as OWNER/REPO
  --config: path # Complete ruleset JSON, defaulting to the shared main ruleset
] {
  let main_ruleset = ($SETTINGS_DIR | path join "rulesets/main.json")
  let source = if $config == null {
    $main_ruleset
  } else {
    $config
  }

  let name = (open --raw $source | from json | get name)
  mut endpoint = $"repos/($repo)/rulesets"
  let id = (
    ^gh api $endpoint
      --paginate
      --jq $".[] | select\(.name == ($name | to json)\) | .id"
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
  let labels_config = ($SETTINGS_DIR | path join "labels.json")
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
