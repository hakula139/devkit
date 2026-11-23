#!/usr/bin/env nu

def --wrapped main [...args: string] {
  $"nix ($args | str join ' ')\n" | save --append $env.CACHIX_PIN_TEST_LOG

  let installable = ($args.1 | str replace --regex '^\.#' "" | str replace --all "." "-")
  print $"/nix/store/stub-($installable)"
}
