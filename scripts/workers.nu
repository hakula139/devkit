#!/usr/bin/env nu

# ==================================================================================================
# Cloudflare Workers
# ==================================================================================================

def --wrapped pnpm [...args: string] {
  if ($env.CLOUDFLARE_API_TOKEN? | is-empty) {
    error make {msg: "Set CLOUDFLARE_API_TOKEN on the Workers step"}
  }
  hide-env GH_TOKEN
  ^nix develop -c pnpm --dir $env.WORKER_DIRECTORY ...$args
}

def deploy [] {
  # An explicit empty environment selects the top-level config even with CLOUDFLARE_ENV set.
  let environment = $"--env=($env.WRANGLER_ENVIRONMENT)"
  if $env.D1_DATABASE != "" {
    (
      pnpm exec wrangler d1 migrations apply $env.D1_DATABASE
        --remote
        $environment
    )
  }
  pnpm run deploy $environment
}

def preview [number: int, sha: string, cleanup: bool] {
  let name = $"pr-($number)"
  $env.WRANGLER_OUTPUT_FILE_PATH = mktemp --tmpdir-path $env.RUNNER_TEMP
  let output = $env.WRANGLER_OUTPUT_FILE_PATH

  if $cleanup {
    let result = (
      pnpm exec wrangler preview delete
        --name $name
        --skip-confirmation
      | complete
    )
    print --no-newline $result.stdout
    print --stderr --no-newline $result.stderr
    if $result.exit_code != 0 {
      # Cloudflare API error 10025 means the preview is already absent.
      let failures = (
        open --raw $output
        | from json --objects
        | where type == "command-failed"
      )
      if ($failures | get code) != [10025] { exit $result.exit_code }
    }
    rm $output
    return {}
  }

  (
    pnpm exec wrangler preview
      --name $name
      --message $"PR #($number) @ ($sha)"
  )
  let record = (
    open --raw $output
    | from json --objects
    | where type == "preview"
    | last
  )
  rm $output
  let preview_url = $record.preview_urls.0
  let deployment_url = $record.deployment_urls.0
  if ([$preview_url $deployment_url] | any {|url| $url !~ '^https://\S+$'}) {
    error make {msg: "Wrangler returned an invalid preview or deployment URL"}
  }
  {
    preview-url: $preview_url
    deployment-url: $deployment_url
  }
}

# Run after checkout, dependency install, and any artifact download.
def main [] {
  if (^git rev-parse HEAD | str trim) != $env.GITHUB_SHA {
    error make {msg: "Check out the event commit before running the Workers action"}
  }

  let outputs = match $env.GITHUB_EVENT_NAME {
    "push" | "workflow_dispatch" if ($env.GITHUB_REF | str starts-with "refs/heads/") => {
      let ref = (
        $env.GITHUB_REF
        | str replace "refs/" ""
        | url encode
      )
      let head = (^gh api $"repos/($env.GITHUB_REPOSITORY)/git/ref/($ref)" | from json).object.sha
      if $head != $env.GITHUB_SHA {
        print $"::notice::Skipping deploy because the branch moved on to ($head)"
        return
      }
      deploy
      {}
    }
    "pull_request" | "pull_request_target" => {
      let event = open $env.GITHUB_EVENT_PATH
      let cleanup = $env.GITHUB_EVENT_NAME == "pull_request_target"
      if $cleanup and $event.action != "closed" {
        error make {msg: "Preview cleanup requires pull_request_target: closed"}
      }

      let pr = $event.pull_request
      if ($pr.head.repo.full_name? != $env.GITHUB_REPOSITORY
        or $pr.user.login == "dependabot[bot]") {
        return
      }
      let live = ^gh api $"repos/($env.GITHUB_REPOSITORY)/pulls/($event.number)" | from json
      let current = if $cleanup {
        $live.state == "closed"
      } else {
        $live.state == "open" and $live.head.sha == $pr.head.sha
      }
      if not $current {
        print "::notice::Skipping Workers preview operation because the pull request changed"
        return
      }
      preview $event.number $pr.head.sha $cleanup
    }
    _ => { error make {msg: "Expected a branch deployment or pull request event"} }
  }

  $outputs
  | insert applied true
  | transpose name value
  | each {|output| $"($output.name)=($output.value)\n"}
  | str join
  | save --append $env.GITHUB_OUTPUT
}
