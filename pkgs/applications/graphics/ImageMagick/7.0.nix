{ stdenv, buildPackages, fetchFromGitHub
, djvulibre, fontconfig, ghostscript, libheif, libpng, libtiff
, libxml2, zlib
, librsvg, openexr, openjpeg
, bzip2, freetype, lcms2, libjpeg
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
    version = "7.0.8-34";
    sha256 = "0szkzwy0jzmwx4kqli21jq8pk3s53v37q0nsaqzascs3mpkbza2s";
    patches = [];
  };
in

stdenv.mkDerivation rec {
  pname = "imagemagick";
  inherit (cfg) version;

  src = fetchFromGitHub {
    owner = "ImageMagick";
    repo = "ImageMagick";
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
  ] ++ optionals stdenv.hostPlatform.isMinGW [
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
    libheif
    libpng
    libtiff
    libxml2
    zlib
  ] ++ optionals (!stdenv.hostPlatform.isMinGW) [
    librsvg
    openexr
    openjpeg
  ] ++ optional stdenv.isDarwin ApplicationServices;

  propagatedBuildInputs = [
    bzip2
    freetype
    lcms2
    libjpeg
  ] ++ optionals (!stdenv.hostPlatform.isMinGW) [
    libX11
    libXext
    libXt
    libwebp
  ];

  postInstall = let inherit (buildPackages) pkgconfig; in ''
    (cd "$dev/include" && ln -s ImageMagick* ImageMagick)
    moveToOutput "bin/*-config" "$dev"
    # includes configure params
    moveToOutput "lib/ImageMagick-*/config-Q16HDRI" "$dev"
    for file in "$dev"/bin/*-config; do
      substituteInPlace "$file" \
        --replace pkg-config \
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
    license = with licenses; asl20;
    maintainers = with maintainers; [ the-kenny ];
  };
}
