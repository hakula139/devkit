# ==================================================================================================
# parse-changelog
# ==================================================================================================

{
  fetchCrate,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "parse-changelog";
  version = "0.6.18";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-KGIGE0zT2Y9Q401J21j9JWgdJVMVvsMMR8KT+alh3kk=";
  };

  cargoHash = "sha256-v880pj27TOeRnK/T1duVr6RaFZLC+vG7Pmr2COJCKqo=";

  # The published crate omits the `test_helper` crate its tests depend on.
  doCheck = false;

  meta.mainProgram = "parse-changelog";
})
