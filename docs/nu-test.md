# Nushell test runner

`nu-test` runs the tests in a set of `.test.nu` files, and `dk.nuTests` wraps it in a Nix check.

## Write a test

A test is a command named `test <behavior>` in a `.test.nu` file, using assertions from `std/assert`. A test name may contain only letters, digits, spaces, and `,.:-`.

- **One process per test.** The runner collects test names from the files and runs the tests in parallel, each in its own `nu` process, so a test that modifies its environment or exits cannot affect the others.
- **Load failures are tests.** A file that fails to parse or whose test names cannot be read reports a `(load)` entry with its output and counts as a failure. A file that prints to stdout or exits while loading cannot report its test names, so it also fails.
- **Stubs.** A `<name>.stub.nu` file beside a test file is installed as an executable `<name>` in the directory given by `NU_TEST_STUBS`. A test calls a stub through `$env.NU_TEST_STUBS | path join <name>` or by prepending that directory to `PATH`.
- **Shared helpers.** A `<name>.testlib.nu` file beside the test files holds builders that several of them `use`. `nuTests` copies it with the test files, and `mkNuApplication` excludes it from the package.
- **Scratch space.** `TMPDIR` points to a fresh empty directory for each test, and the runner removes these directories after the run, even if the file fails to load.
- **Exit codes.** The runner prints one `PASS` or `FAIL` line per test and a `passed, failed` summary, then exits nonzero if any test fails or no tests run.

## Run the check

`nuTests` takes `src` and an optional `runtimeInputs` list, as shown in [Nushell tooling](nushell.md):

- The check copies every directory containing a test file and runs those files from the `src` root with `dk.nushell` and `runtimeInputs` on `PATH`.
- Run `chmod u+w` on any file copied by a test before writing to it.
- A test that sources a path outside its copied directory fails in the sandbox.

## Run one file directly

Add `dk.nushell` and `dk.nu-test` to the dev shell's `packages` (which [Nix flake](flake.md) shows how to define) so `nu` matches the check's Nushell and `nu-test` is on `PATH`. Because the check runs from the `src` root, reproduce a failure by running `nu-test <file>...` from that root with relative paths.

## Check a script without running it

`dk.nu-check` runs Nushell's `--ide-check` on each file to catch mismatched delimiters and wrong argument counts in calls to local `def`s. Because Nushell treats a mistyped command as an external call, run the script once for real too. Diagnostics take these forms:

- A file's own error prints as `<file>:<line>:<column>: <message>`, the format editors link. The column counts bytes, matching Nushell's own diagnostics.
- An error inside a module the file loads prints as `<file>: <message> (in a module it loads)`.
- A missing or non-UTF-8 file prints as `<file>: <reason>`.

[Hooks](hooks.md) covers the baseline's `nu-check` hook.
