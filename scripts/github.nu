#!/usr/bin/env nu

# ==================================================================================================
# GitHub Administration
# ==================================================================================================

const SETTINGS_DIR = path self "../.github/settings"
const ACTIONS_APP_ID = 15368

# Bind a required check to the app in its trailing @APP-ID, or to GitHub Actions without one.
def required-check [check: string]: nothing -> record {
  let app_check = ($check | parse --regex '^(?<context>.+)@(?<id>\d+)$')
  if ($app_check | is-empty) {
    {context: $check, integration_id: $ACTIONS_APP_ID}
  } else {
    {context: $app_check.0.context, integration_id: ($app_check.0.id | into int)}
  }
}

# Show the repository administration commands.
def main [] {
  help main
}

# Apply repository and workflow settings, security defaults, and immutable releases.
def "main settings" [
  repo: string # Target repository as OWNER/REPO
  --private # Skip private vulnerability reporting and secret scanning for a private repository
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

  if $private {
    print -e "Skipped private vulnerability reporting for a private repository."
    print -e "Skipped secret scanning for a private repository."
  } else {
    ^gh api $"repos/($repo)/private-vulnerability-reporting" --method PUT
    (
      ^gh api $"repos/($repo)"
        --method PATCH
        --input $security_settings
    )
  }

  ^gh api $"repos/($repo)/immutable-releases" --method PUT
}

# Create or replace the shared main ruleset, adding any extra required checks.
def "main ruleset" [
  repo: string # Target repository as OWNER/REPO
  ...checks: string # Extra required checks as CONTEXT from GitHub Actions or CONTEXT@APP-ID
  --private # Skip the ruleset for a private repository
] {
  if $private {
    print -e "Skipped the ruleset for a private repository."
    return
  }

  let main_ruleset = ($SETTINGS_DIR | path join "rulesets/main.json")
  let required = ($checks | each {|check| required-check $check })
  let ruleset = (
    open $main_ruleset
    | update rules {
      each {|rule|
        if $rule.type == "required_status_checks" {
          $rule | update parameters.required_status_checks { append $required }
        } else {
          $rule
        }
      }
    }
  )

  mut endpoint = $"repos/($repo)/rulesets"
  let id = (
    ^gh api $endpoint
      --paginate
      --jq $".[] | select\(.name == ($ruleset.name | to json)\) | .id"
    | str trim
  )

  mut method = "POST"
  if $id != "" {
    $endpoint = $"($endpoint)/($id)"
    $method = "PUT"
  }

  (
    $ruleset
    | to json
    | ^gh api $endpoint
      --method $method
      --input -
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
