#!/usr/bin/env nu

# ==================================================================================================
# gh Stub
# ==================================================================================================

def "main auth status" [--hostname: string] {
  if $hostname != "github.com" {
    exit 1
  }
}

def "main api" [endpoint: string, --hostname: string, --jq: string] {
  if (
    $endpoint != "repos/example/sample/releases/latest"
    or $hostname != "github.com"
    or $jq != ".tag_name"
  ) {
    print -e "unexpected GitHub API request"
  } else {
    print -e "gh: Service unavailable (HTTP 503)"
  }
  exit 1
}

def main [] {
  exit 1
}
