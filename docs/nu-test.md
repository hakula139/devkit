# Nushell test runner

`nu-test` runs the tests in a set of `.test.nu` files, and `dk.nuTests` wraps it in a Nix check.

## Write a test

A test is a command named `test <behavior>` in a `.test.nu` file, with assertions from `std/assert`. A test name may hold only letters, digits, spaces, and `,.:-`, since the runner passes it to `nu --commands` as source text, where a quote, `;`, or `#` ends or breaks the command.

- **One process per test.** The runner collects test names from the files and runs the tests in parallel, each in its own `nu` process, so a test that changes its environment or exits cannot affect the others.
- **Load failures are tests.** A file that fails to parse or whose test names cannot be read reports a `(load)` entry with its output and counts as a failure. A file that prints to stdout or exits while loading cannot report its test names, so it fails too.
- **Stubs.** A `<name>.stub.nu` file beside a test file is installed as an executable `<name>` in the directory named by `NU_TEST_STUBS`, with a shebang line the runner writes in place of any the stub has. A test calls a stub by `$env.NU_TEST_STUBS | path join <name>` or by prepending that directory to `PATH`.
- **Shared helpers.** A `<name>.testlib.nu` file beside the test files holds builders that several of them `use`. `nuTests` copies it with the test files, and `mkNuApplication` leaves it out of the package.
- **Scratch space.** `TMPDIR` points to a fresh empty directory for each test, and the runner removes these directories after the run, even if the file fails to load.
- **Exit codes.** The runner prints one `PASS` or `FAIL` line per test and a `passed, failed` summary, then exits nonzero if any test fails or no tests run.

## Run the check

`nuTests` takes `src` and an optional `runtimeInputs` list, as the [README](../README.md#adopt-the-nushell-tooling) shows. The check copies every directory containing a test file and runs those files from the `src` root with `dk.nushell` and `runtimeInputs` on `PATH`. Because the copy is read-only and `cp` preserves modes, run `chmod u+w` on any file the test copies before writing to it. A test that sources a path outside its copied directory fails in the sandbox.

## Run one file directly

Add `dk.nushell` and `dk.nu-test` to the dev shell's `packages`, which the [README](../README.md#adopt-the-flake) shows how to define, so `nu` is the check's Nushell and `nu-test` is on `PATH`. Because the check runs from the `src` root, reproduce a failure by running `nu-test <file>...` from there with paths relative to it.

## Check a script without running it

`dk.nu-check` runs Nushell's `--ide-check` on each file, which catches mismatched delimiters and the arity of local `def`s, but it treats a mistyped command as an external call, so run the script once for real too. It prints each error as `<file>:<line>:<column>: <message>`, the form editors link, and counts the column in bytes, as Nushell's own diagnostics do. An error inside a module the file loads prints as `<file>: <message> (in a module it loads)`, and a missing or non-UTF-8 file prints as `<file>: <reason>`.

[Hooks](hooks.md) covers the baseline's `nu-check` hook and why no hook runs `nufmt`.
