# ==================================================================================================
# GC Root Link Stub
# ==================================================================================================
# The build sandbox cannot register GC roots in the host store.
# cspell:ignore realise

use std/assert

def --wrapped main [...args: string] {
  assert equal ($args | length) 5
  assert equal [$args.0 $args.2 $args.3] ["--add-root" "--indirect" "--realise"]

  ^ln -s $args.4 $args.1
}
