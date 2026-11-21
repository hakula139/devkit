# Nushell test runner

## Write a test

Define each test as a `test <behavior>` command in a `.test.nu` file beside the code it exercises, using `std/assert` for assertions. See the [test file](../tests/nu-tooling/lib-dirs/lib-dirs.test.nu) for an example and the [Nushell testing conventions](https://github.com/hakulab/plugins/blob/main/plugins/hakula-languages/skills/nushell/SKILL.md#testing) for guidance on assertions and fixtures.

- Choose **test names** made up of ASCII letters, digits, or `,.:-`, with one space between words and no trailing space. The runner reads the command names after the file loads, so keep stdout empty and let loading finish. If discovery fails, the runner reports a failed `(load)` entry.
- Tests **run in parallel**, each in a fresh Nushell process, so one test cannot rely on environment changes made by another. Write temporary files in the test's own empty `TMPDIR`, which the runner cleans up afterward.
- Keep **fixtures** beside the tests that read them. Since inputs from the Nix store are read-only, copy a fixture into `TMPDIR` and run `chmod u+w` on the copy before modifying it.
- Put **shared helpers** in a sibling `<name>.testlib.nu` so several tests can import the same builders. The Nix check includes this file, and the application builder leaves it out of the package.
- To **stub an executable**, place `<name>.stub.nu` beside the test file. The runner installs it under `NU_TEST_STUBS` as `<name>`. Call it there directly, or prepend that directory to `PATH` if a child process needs to find the stub by name.

The [runner](../src/nu-test.nu) prints a result for each test followed by the totals, and exits nonzero if discovery fails, a test fails, or no tests run.

## Run the check

After [setting up the flake](flake.md), add the check to the per-system outputs.

```nix
checks.tests = dk.nuTests {
  src = ./.;
};
```

The [Nix check](../nix/nu-test-check.nix) requires at least one `.test.nu` file under `src`. It copies each directory that contains a test file, so a test at the root of `src` brings in the whole tree. Tests run from the root of that copy, where a relative import can fail if it points to a file outside the copied directories.

- Add any packages that provide external commands used by the tests to `runtimeInputs`.
- If a test imports modules by name, pass the package's [module directories](nushell.md#share-modules) to `libDirs`, as in the [check](../tests/nu-tooling/lib-dirs/default.nix). When a test starts `nu` or `nu-check`, the child needs `NU_LIB_DIRS` as a string. The [test](../tests/nu-tooling/lib-dirs/lib-dirs.test.nu) shows how to pass `$env.NU_LIB_DIRS | str join (char esep)` in `with-env`.

## Run one file directly

To reproduce a failure with the same interpreter and working directory as the Nix check, add `dk.nushell` and `dk.nu-test` to the dev shell and run `nu-test path/to/file.test.nu` from the check's `src` directory.

## Check a script without running it

The [`nu-check` hook](hooks.md) reports Nushell diagnostics. Run the script as well, since Nushell can interpret a mistyped command name as an external executable.

- `<file>:<line>:<column>: <message>` locates an error in the checked file, with a one-based byte column.
- `<file>: <message> (in a module it loads)` reports an error in an imported module.
- `<file>: <reason>` reports a file the checker could not read as UTF-8, including a missing file.
