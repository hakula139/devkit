# Nushell test runner

## Write a test

Define `test <behavior>` commands in a `.test.nu` file beside the code they exercise. Use `std/assert` for assertions. See a [test file](../tests/nu-tooling/lib-dirs/lib-dirs.test.nu) and the [Nushell testing conventions](https://github.com/hakulab/plugins/blob/main/plugins/hakula-languages/skills/nushell/SKILL.md#testing).

- **Discovery.** Use ASCII letters, digits, or `,.:-` in each word of a test name, with single spaces between words and no trailing space. Keep stdout empty and let the file finish loading so the runner can collect the command names. A discovery error appears as a failed `(load)` entry.
- **Isolation.** Tests run in parallel, each in a fresh Nushell process with its own empty `TMPDIR`. Write there and let the runner clean it up. A test cannot rely on environment changes made by another test.
- **Fixtures.** Keep fixtures beside the tests that read them. To modify a fixture, copy it into `TMPDIR` and run `chmod u+w` on the copy, since inputs from the Nix store are read-only.
- **Shared helpers.** Put builders that several tests import in a sibling `<name>.testlib.nu`. The test check includes this file and the application builder excludes it.
- **Stubs.** A sibling `<name>.stub.nu` supplies an executable named `<name>` under `NU_TEST_STUBS`. Call that path directly, or prepend the directory to `PATH` in a test whose child must find the stub by name.

The [runner](../src/nu-test.nu) prints each test's result and the totals. It exits nonzero when discovery or a test fails, or when no tests run.

## Run the check

After [setting up the flake](flake.md), add the check to the per-system outputs.

```nix
checks.tests = dk.nuTests {
  src = ./.;
};
```

The [Nix check](../nix/nu-test-check.nix) requires at least one `.test.nu` file under `src`. It copies the directories containing those files and runs from the resulting `src` root. A test at the root includes the whole tree. A relative import may work in the checkout and fail in the sandbox if its target is outside the copied directories.

- For external commands, add their packages to `runtimeInputs`.
- For named modules, pass the package's [module directories](nushell.md#share-modules) to `libDirs`. A test that starts `nu` or `nu-check` must pass `NU_LIB_DIRS` as a string using `$env.NU_LIB_DIRS | str join (char esep)` in `with-env`. See the [check](../tests/nu-tooling/lib-dirs/default.nix) and [test](../tests/nu-tooling/lib-dirs/lib-dirs.test.nu).

## Run one file directly

Add `dk.nushell` and `dk.nu-test` to the dev shell and run `nu-test path/to/file.test.nu` from the check's `src` directory to reproduce its working directory and interpreter.

## Check a script without running it

Use the [`nu-check` hook](hooks.md) for Nushell diagnostics. Exercise the script too, since Nushell can interpret a mistyped command name as an external executable.

- `<file>:<line>:<column>: <message>` locates an error in the checked file. The one-based column counts bytes.
- `<file>: <message> (in a module it loads)` points to an error in an imported module.
- `<file>: <reason>` reports a file the checker could not read as UTF-8, including a missing file.
