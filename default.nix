let 
  pkgs = import ./pkgs.nix;

  buildHtml = name: page: pkgs.conix.build.pandoc "html" name [ page ];

  paths = 
    pkgs.lib.attrsets.mapAttrsToList buildHtml
      (pkgs.conix.buildPages
        [ (import ./contents/why-fp-eaql.nix)
          (import ./contents/index.nix)
        ]
      ).posts;
in
pkgs.runCommand "zettelkasten" {passAsFile = [ "paths" ]; inherit paths;}
  
  ''
  mkdir -p $out
  for i in $(cat $pathsPath); do
    cp $i/*.html $out/
  done
  ''
