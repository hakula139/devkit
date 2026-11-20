use std/assert

def "test packages multi-file application with clean help name and skills" [] {
  let app_root = (which echo-app | first | get path | path dirname | path dirname)

  let help = (^echo-app --help | complete)
  let result = (^echo-app "world" | complete)

  assert equal $help.exit_code 0
  assert equal $help.stderr ""
  assert str contains $help.stdout "> echo-app"
  assert not ($help.stdout | str contains "echo-app.nu")
  assert equal $result.exit_code 0
  assert equal $result.stderr ""
  assert equal ($result.stdout | from nuon) {
    mode: "app mode"
    target: "world"
  }
  assert (($app_root | path join "share/skills/skill/SKILL.md") | path exists)
  assert not (($app_root | path join "share/echo-app/ignored.testlib.nu") | path exists)
}
