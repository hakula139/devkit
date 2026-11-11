# ==================================================================================================
# Dprint Configuration
# ==================================================================================================

{
  pkgs,
  dprint-plugin-markdown,
}:

pkgs.writers.writeJSON "dprint.json" {
  markdown = {
    emphasisKind = "underscores";
    strongKind = "asterisks";
    "codeBlock.preserveIndentation" = true;
    "codeBlock.preserveBlankLines" = true;
    "html.skipFormat" = true;
  };

  # Language plugins would also rewrite fenced examples inside Markdown.
  plugins = [ "${dprint-plugin-markdown}/plugin.wasm" ];
}
