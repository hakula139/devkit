#!/usr/bin/env nu

def --wrapped main [...args: string] {
  $"cachix ($args | str join ' ')\n" | save --append $env.CACHIX_PIN_TEST_LOG
}
