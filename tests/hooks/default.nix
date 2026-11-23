# ==================================================================================================
# Hooks Check
# ==================================================================================================

{
  pkgs,
  dk,
}:

let
  preCommit = dk.preCommit {
    src = ./.;
  };
in
pkgs.runCommand "hooks"
  {
    nativeBuildInputs = [ pkgs.git ] ++ preCommit.nativeBuildInputs;
  }
  ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$HOME" "$XDG_CACHE_HOME" repo
    cd repo

    git init -q
    git config user.email test@example.com
    git config user.name Test

    excluded=(
      __fixtures__/data.txt
      nested/__fixtures__/data.txt
      fixtures/data.txt
      nested/fixtures/data.txt
      __snapshots__/data.snap
      nested/__snapshots__/data.snap
      testdata/data.json
      nested/testdata/data.json
    )

    for file in "''${excluded[@]}" src/data.txt; do
      mkdir -p "$(dirname "$file")"
      printf 'line   \n' >"$file"
    done

    git add .

    if run-hooks trim-trailing-whitespace; then
      echo "expected trim-trailing-whitespace to fail on src/data.txt" >&2
      exit 1
    fi

    diff -u <(printf 'line\n') src/data.txt

    for file in "''${excluded[@]}"; do
      diff -u <(printf 'line   \n') "$file"
    done

    run-hooks trim-trailing-whitespace
    touch "$out"
  ''
