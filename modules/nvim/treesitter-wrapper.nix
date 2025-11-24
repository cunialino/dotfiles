{ pkgs }:

let
  # Extract language name from tree-sitter package name
  # e.g., "tree-sitter-rust" -> "rust"
  extractLang = pkg: 
    let
      name = pkg.pname or (builtins.parseDrvName pkg.name).name;
      match = builtins.match "tree-sitter-([^-]+)(-grammar)?" name;
    in
      if match != null then builtins.head match else name;

  # Process a single grammar package
  processGrammar = pkg:
    let
      lang = extractLang pkg;
    in ''
      # Copy parser
      if [ -f ${pkg}/parser ]; then
        cp ${pkg}/parser $out/parser/${lang}.so
      fi
      
      # Copy queries if they exist
      if [ -d ${pkg}/queries ]; then
        mkdir -p $out/queries/${lang}
        cp -r ${pkg}/queries/* $out/queries/${lang}/
      fi
    '';

  # Create the combined treesitter directory
  mkTreesitterDir = grammars:
    pkgs.runCommand "nvim-treesitter-grammars" {} ''
      mkdir -p $out/parser
      mkdir -p $out/queries
      
      ${builtins.concatStringsSep "\n" (map processGrammar grammars)}
    '';

in
{
  inherit mkTreesitterDir;
  
  # Convenience function for use in Neovim config
  mkTreesitterPackage = grammars: {
    type = "path";
    path = mkTreesitterDir grammars;
  };
}
