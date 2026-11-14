# ==================================================================================================
# Actionlint
# ==================================================================================================

{
  pkgs,
}:

pkgs.actionlint.overrideAttrs (old: {
  # Unreleased upstream fixes. Drop each patch once a release contains it.
  patches = (old.patches or [ ]) ++ [
    # https://github.com/rhysd/actionlint/pull/654
    (pkgs.fetchpatch {
      url = "https://github.com/rhysd/actionlint/commit/644076a59742c2d1540ebd4686eab3c308f0e562.patch";
      hash = "sha256-Lpd7CTkLbzgvAZV2H8G4GTUoPNDCK7PiW3A40+cquUk=";
    })
    # https://github.com/rhysd/actionlint/pull/668
    (pkgs.fetchpatch {
      url = "https://github.com/rhysd/actionlint/commit/8ff976ea0b8a87eef436c1b789fef94af462dfa7.patch";
      hash = "sha256-UHS0/jUhWsIYXOpRXiIikDjixJ4B6oSfTiVGS/O64rU=";
    })
    # https://github.com/rhysd/actionlint/issues/650
    (pkgs.fetchpatch {
      url = "https://github.com/rhysd/actionlint/commit/fd33e9f582a01a02885c93ae3775e1190cf63653.patch";
      hash = "sha256-PbdXDn6tG4Ii2xXDauJ0b3+tWqTIcv0J8keUWdAxWmU=";
    })
  ];
})
