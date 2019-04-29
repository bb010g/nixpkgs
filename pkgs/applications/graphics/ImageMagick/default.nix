{ stdenv, buildPackages, fetchFromGitHub, fetchpatch
, djvulibre, fontconfig, ghostscript, libde265, libheif, libpng, libtiff
, libxml2, zlib
, librsvg, openexr, openjpeg
, bzip2, fftw, freetype, lcms2, libjpeg
, libX11, libXext, libXt, libwebp
, ApplicationServices
}:

let
  inherit (stdenv.lib) optional optionalAttrs optionalString optionals;

  arch = let inherit (stdenv.hostPlatform) system; in
    if system == "i686-linux" then "i686"
    else if system == "x86_64-linux" || system == "x86_64-darwin" then "x86-64"
    else if system == "armv7l-linux" then "armv7l"
    else if system == "aarch64-linux" then "aarch64"
    else throw "ImageMagick is not supported on this platform.";

  cfg = {
    version = "6.9.9-34";
    sha256 = "0sqrgyfi7i7x1akna95c1qhk9sxxswzm3pkssfi4w6v7bn24g25g";
    patches = [];
  }
    # Freeze version on mingw so we don't need to port the patch too often.
    # FIXME: This version has multiple security vulnerabilities
    // optionalAttrs (stdenv.hostPlatform.isMinGW) {
        version = "6.9.2-0";
        sha256 = "17ir8bw1j7g7srqmsz3rx780sgnc21zfn0kwyj78iazrywldx8h7";
        patches = [(fetchpatch {
          name = "mingw-build.patch";
          url = "https://raw.githubusercontent.com/Alexpux/MINGW-packages/"
            + "01ca03b2a4ef/mingw-w64-imagemagick/002-build-fixes.patch";
          sha256 = "1pypszlcx2sf7wfi4p37w1y58ck2r8cd5b2wrrwr9rh87p7fy1c0";
        })];
      };
in

stdenv.mkDerivation rec {
  pname = "imagemagick";
  inherit (cfg) version;

  src = fetchFromGitHub {
    owner = "ImageMagick";
    repo = "ImageMagick6";
    rev = cfg.version;
    inherit (cfg) sha256;
  };

  patches = [ ./imagetragick.patch ] ++ cfg.patches;

  outputs = [ "out" "dev" "doc" ]; # bin/ isn't really big
  outputMan = "out"; # it's tiny

  enableParallelBuilding = true;

  configureFlags = [
    "--with-frozenpaths"
    "--with-gcc-arch=${arch}"
  ] ++ optional (librsvg != null) (
    "--with-rsvg"
  ) ++ optionals (ghostscript != null) [
    "--with-gs-font-dir=${ghostscript}/share/ghostscript/fonts"
    "--with-gslib"
  ] ++ optionals (stdenv.hostPlatform.isMinGW) [
    # due to libxml2 being without DLLs ATM
    "--enable-static"
    "--disable-shared"
  ];

  nativeBuildInputs = [
    buildPackages.libtool
    buildPackages.pkgconfig
  ];

  buildInputs = [
    djvulibre
    fontconfig
    ghostscript
    libde265
    libheif
    libpng
    libtiff
    libxml2
    zlib
  ] ++ optionals (!stdenv.hostPlatform.isMinGW) [
    librsvg
    openexr
    openjpeg
  ] ++ optional stdenv.isDarwin
    ApplicationServices;

  propagatedBuildInputs = [
    bzip2
    fftw
    freetype
    lcms2
    libjpeg
  ] ++ optionals (!stdenv.hostPlatform.isMinGW) [
    libX11
    libXext
    libXt
    libwebp
  ];

  doCheck = false; # fails 6 out of 76 tests

  postInstall = let inherit (buildPackages) pkgconfig; in ''
    (cd "$dev/include" && ln -s ImageMagick* ImageMagick)
    moveToOutput "bin/*-config" "$dev"
    # includes configure params
    moveToOutput "lib/ImageMagick-*/config-Q16" "$dev"
    for file in "$dev"/bin/*-config; do
      substituteInPlace "$file" \
        --replace "${pkgconfig}/bin/pkg-config -config" \
          ${pkgconfig}/bin/pkg-config
      substituteInPlace "$file" \
        --replace ${pkgconfig}/bin/pkg-config \
          "PKG_CONFIG_PATH='$dev/lib/pkgconfig' '${pkgconfig}/bin/pkg-config'"
    done
  '' + optionalString (ghostscript != null) ''
    for la in "$out"/lib/*.la; do
      sed 's|-lgs|-L${stdenv.lib.getLib ghostscript}/lib -lgs|' -i "$la"
    done
  '';

  meta = with stdenv.lib; {
    homepage = http://www.imagemagick.org/;
    description =
      "A software suite to create, edit, compose, or convert bitmap images";
    platforms = with platforms; linux ++ darwin;
    maintainers = with maintainers; [ the-kenny ];
    license = with licenses; asl20;
  };
}
