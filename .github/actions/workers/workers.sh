#!/usr/bin/env bash

# ==================================================================================================
# Cloudflare Workers
# ==================================================================================================

set -euo pipefail

if [[ "$(git rev-parse HEAD)" != "$GITHUB_SHA" ]]; then
  echo "::error::Check out the event commit before running the Workers action."
  exit 1
fi

case "$OPERATION" in
  deploy)
    if [[ "$GITHUB_EVENT_NAME" != push && "$GITHUB_EVENT_NAME" != workflow_dispatch ]] \
      || [[ "$GITHUB_REF" != refs/heads/* ]]; then
      echo "::error::Branch deployments require a push or workflow_dispatch on a branch."
      exit 1
    fi

    ref=$(
      jq \
        -nr \
        --arg ref "${GITHUB_REF#refs/}" \
        '$ref | split("/") | map(@uri) | join("/")'
    )
    head=$(gh api "repos/$GITHUB_REPOSITORY/git/ref/$ref" --jq '.object.sha')
    if [[ "$head" != "$GITHUB_SHA" ]]; then
      echo "::notice::Skipping deployment because the branch has moved on to $head."
      exit 0
    fi
    ;;

  preview | cleanup)
    event=pull_request
    if [[ "$OPERATION" == cleanup ]]; then
      event=pull_request_target
    fi

    if [[ "$GITHUB_EVENT_NAME" != "$event" ]]; then
      echo "::error::The $OPERATION operation requires the $event event."
      exit 1
    fi
    if [[ "$OPERATION" == cleanup && "$(jq -er '.action' "$GITHUB_EVENT_PATH")" != closed ]]; then
      echo "::error::Preview cleanup requires a closed event."
      exit 1
    fi

    if ! jq \
      -e \
      --arg repo "$GITHUB_REPOSITORY" \
      '.pull_request | .head.repo.full_name == $repo and .user.login != "dependabot[bot]"' \
      "$GITHUB_EVENT_PATH" \
      >/dev/null; then
      echo "::notice::Skipping a fork or Dependabot pull request."
      exit 0
    fi

    pr_number=$(jq -er '.number' "$GITHUB_EVENT_PATH")
    pr_sha=$(jq -er '.pull_request.head.sha' "$GITHUB_EVENT_PATH")
    live_pr=$(gh api "repos/$GITHUB_REPOSITORY/pulls/$pr_number")
    if [[ "$OPERATION" == preview ]]; then
      current=$(
        jq \
          -r \
          --arg sha "$pr_sha" \
          '.state == "open" and .head.sha == $sha' \
          <<<"$live_pr"
      )
      if [[ "$current" != true ]]; then
        echo "::notice::Skipping preview because the pull request closed or its head changed."
        exit 0
      fi
    elif [[ "$(jq -er '.state' <<<"$live_pr")" != closed ]]; then
      echo "::notice::Skipping cleanup because the pull request reopened."
      exit 0
    fi
    ;;

  *)
    echo "::error::Workers operation must be deploy, preview, or cleanup."
    exit 1
    ;;
esac

unset GH_TOKEN
: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN on the Workers step.}"
wrangler=(nix develop -c pnpm --dir "$WORKER_DIRECTORY" exec wrangler)

if [[ "$OPERATION" != deploy ]]; then
  WRANGLER_OUTPUT_FILE_PATH=$(mktemp "${RUNNER_TEMP}/wrangler.XXXXXX")
  export WRANGLER_OUTPUT_FILE_PATH
  trap 'rm -f "$WRANGLER_OUTPUT_FILE_PATH"' EXIT
fi

case "$OPERATION" in
  deploy)
    # An explicit empty environment selects the top-level config even with CLOUDFLARE_ENV set.
    deploy_args=(--env "$WRANGLER_ENVIRONMENT")
    if [[ "$MINIFY" == true ]]; then
      deploy_args+=(--minify)
    fi

    if [[ -n "$D1_DATABASE" ]]; then
      "${wrangler[@]}" d1 migrations apply "$D1_DATABASE" \
        --remote \
        --env "$WRANGLER_ENVIRONMENT"
    fi
    "${wrangler[@]}" deploy "${deploy_args[@]}"
    ;;

  preview)
    "${wrangler[@]}" preview \
      --name "pr-$pr_number" \
      --message "PR #$pr_number @ $pr_sha"

    jq -ers '
      def url: strings | select(test("^https://[^[:space:]]+$"));
      map(select(.type == "preview")) | last
      | (.preview_urls[0] | url) as $preview
      | (.deployment_urls[0] | url) as $deployment
      | "preview-url=\($preview)\ndeployment-url=\($deployment)"
    ' "$WRANGLER_OUTPUT_FILE_PATH" >>"$GITHUB_OUTPUT"
    ;;

  cleanup)
    if ! "${wrangler[@]}" preview delete \
      --name "pr-$pr_number" \
      --skip-confirmation; then
      # Cloudflare API error 10025 means the preview is already absent.
      jq -es 'map(select(.type == "command-failed") | .code) == [10025]' \
        "$WRANGLER_OUTPUT_FILE_PATH" >/dev/null
    fi
    ;;
esac

echo "applied=true" >>"$GITHUB_OUTPUT"
