# ==================================================================================================
# Actionlint
# ==================================================================================================

{
  actionlint,
  fetchpatch,
}:

actionlint.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    (fetchpatch {
      url = "https://github.com/rhysd/actionlint/commit/644076a59742c2d1540ebd4686eab3c308f0e562.patch";
      hash = "sha256-Lpd7CTkLbzgvAZV2H8G4GTUoPNDCK7PiW3A40+cquUk=";
    })
    (fetchpatch {
      url = "https://github.com/rhysd/actionlint/commit/8ff976ea0b8a87eef436c1b789fef94af462dfa7.patch";
      hash = "sha256-UHS0/jUhWsIYXOpRXiIikDjixJ4B6oSfTiVGS/O64rU=";
    })
  ];
})
