{
  pkgs,
  shfmt,
}:

pkgs.runCommand "devkit-shfmt" { } ''
  work="$PWD"
  mkdir -p clean/home clean/project poisoned/home poisoned/project
  cp ${./fixtures/shfmt/poisoned.editorconfig} poisoned/.editorconfig
  cp ${./fixtures/shfmt/poisoned.editorconfig} poisoned/home/.editorconfig

  for context in clean poisoned; do
    cp ${./fixtures/shfmt/input.sh} "$context/project/example.sh"

    (
      cd "$context/project"
      HOME="$work/$context/home" ${shfmt.entry} example.sh
    )
  done

  diff -u clean/project/example.sh poisoned/project/example.sh
  diff -u ${./fixtures/shfmt/expected.sh} clean/project/example.sh
  touch "$out"
''
