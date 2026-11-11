# ==================================================================================================
# Dprint Markdown Plugin
# ==================================================================================================

{
  pkgs,
}:

pkgs.dprint-plugins.dprint-plugin-markdown.overrideAttrs (_: {
  # Current nixpkgs pins 0.20.0, which rewrites protected content.
  version = "0.29.0";

  src = pkgs.fetchurl {
    url = "https://plugins.dprint.dev/markdown-0.29.0.wasm";
    hash = "sha256-cUrqdVXdmDGGG+Rm2osmstkjFtPN5VDvPh9jsx9OowI=";
  };
})
