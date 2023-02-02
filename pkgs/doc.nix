{ self, pkgs }:

let
  version =
    if self.sourceInfo ? revCounf
    then with self.sourceInfo; "${revCount}-${shortRev}"
    else "dirty";
  inherit (self.sourceInfo) lastModified;
in

{
  doc-html = pkgs.stdenv.mkDerivation rec {
    name = "skyflake-doc-html-${version}";
    inherit version;
    src = ../doc;
    buildInputs = with pkgs.python3Packages; [
      sphinx
      sphinx_rtd_theme
      myst-parser
    ];
    buildPhase = ''
      export SOURCE_DATE_EPOCH=${toString lastModified}
      make html
    '';
    installPhase = ''
      cp -r _build/html $out
      mkdir $out/nix-support
      echo doc manual $out index.html >> $out/nix-support/hydra-build-products
    '';
  };
  doc-pdf = pkgs.stdenv.mkDerivation rec {
    name = "skyflake-doc-pdf-${version}";
    inherit version;
    src = ../doc;
    buildInputs = [ (pkgs.texlive.combine {
      inherit (pkgs.texlive)
        scheme-basic latexmk cmap collection-fontsrecommended fncychap
        titlesec tabulary varwidth framed fancyvrb float wrapfig parskip
        upquote capt-of needspace etoolbox;
    }) ] ++ (with pkgs.python3Packages; [
      sphinx
      sphinx_rtd_theme
      myst-parser
    ]);
    buildPhase = ''
      export SOURCE_DATE_EPOCH=${toString lastModified}
      make latexpdf
    '';
    installPhase = ''
      mkdir $out
      cp _build/latex/skyflake.pdf $out
      mkdir $out/nix-support
      echo doc-pdf manual $out skyflake.pdf >> $out/nix-support/hydra-build-products
    '';
  };
}
