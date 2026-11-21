# Nushell test runner

## Write a test

Define commands named `test <behavior>` in a `.test.nu` file and use `std/assert` for assertions. Name tests with space-separated words and keep stdout empty while the file loads so the runner can read the discovered names. See a [test file](../tests/nu-tooling/lib-dirs/lib-dirs.test.nu) and the [runner](../src/nu-test.nu).

Use the test's `TMPDIR` for writes. Keep fixtures, `.testlib.nu` helpers, and `<name>.stub.nu` sources beside the tests that use them so the [Nix check](../nix/nu-test-check.nix) includes them in the sandbox. Call a stub by its path under `NU_TEST_STUBS` or prepend that directory to `PATH`. Make a fixture copy writable before modifying it.

## Run the check

After [setting up the flake](flake.md), add the check to the per-system outputs.

```nix
checks.tests = dk.nuTests {
  src = ./.;
};
```

For external commands or named modules, see the [check with `runtimeInputs` and `libDirs`](../tests/nu-tooling/lib-dirs/default.nix). Nushell needs `NU_LIB_DIRS` as a string when passing it to an external command. The [module test](../tests/nu-tooling/lib-dirs/lib-dirs.test.nu) shows how to pass it to `nu-check`.

## Run one file directly

Add `dk.nushell` and `dk.nu-test` to the dev shell and run `nu-test path/to/file.test.nu` from the check's `src` directory to reproduce its working directory and interpreter.

## Check a script without running it

Use the [`nu-check` hook](hooks.md) for Nushell diagnostics. Exercise the script too, since Nushell can interpret a mistyped command name as an external executable.
