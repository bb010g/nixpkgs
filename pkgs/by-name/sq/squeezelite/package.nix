packageArgs@{
  lib,
  stdenv,
  darwin ? null,
  fetchFromGitHub,
  flac,
  libgpiod,
  libmad,
  libpulseaudio,
  libvorbis,
  mpg123,
  audioBackend ? null,
  alsaSupport ? null,
  alsa-lib,
  dsdSupport ? null,
  faad2Support ? null,
  faad2,
  ffmpegSupport ? null,
  ffmpeg,
  opusSupport ? null,
  opusfile,
  pulseSupport ? null,
  resampleSupport ? null,
  soxr,
  sslSupport ? null,
  openssl,
  portaudioSupport ? null,
  portaudio,
  slimserver,
}:

let
  inherit (lib) optional optionals optionalString;

  nonNullOr = default: e: if e == null then default else e;

  audioBackend =
    nonNullOr (if stdenv.hostPlatform.isLinux then "alsa" else "portaudio")
      packageArgs.audioBackend or null;

  alsaBackend = audioBackend == "alsa";
  alsaSupport = nonNullOr alsaBackend packageArgs.alsaSupport or null;
  portaudioBackend = audioBackend == "portaudio";
  portaudioSupport = nonNullOr portaudioBackend packageArgs.portaudioSupport or null;
  pulseBackend = audioBackend == "pulse";
  pulseSupport = nonNullOr pulseBackend packageArgs.pulseSupport or null;

  dsdSupport = nonNullOr true packageArgs.dsdSupport or null;
  faad2Support = nonNullOr true packageArgs.faad2Support or null;
  ffmpegSupport = nonNullOr true packageArgs.ffmpegSupport or null;
  opusSupport = nonNullOr true packageArgs.opusSupport or null;
  resampleSupport = nonNullOr true packageArgs.resampleSupport or null;
  sslSupport = nonNullOr true packageArgs.sslSupport or null;

  binName = "squeezelite${optionalString pulseBackend "-pulse"}";

  appleSdkPackages = darwin.apple_sdk_11_0.frameworks;
in
assert alsaBackend -> alsaSupport;
assert pulseBackend -> pulseSupport;

assert stdenv.hostPlatform.isDarwin -> darwin != null;
stdenv.mkDerivation {
  # the nixos module uses the pname as the binary name
  pname = binName;
  # versions are specified in `squeezelite.h`
  # see https://github.com/ralph-irving/squeezelite/issues/29
  version = "2.0.0.1488";

  src = fetchFromGitHub {
    owner = "ralph-irving";
    repo = "squeezelite";
    rev = "0e85ddfd79337cdc30b7d29922b1d790600bb6b4";
    hash = "sha256-FGqo/c74JN000w/iRnvYUejqnYGDzHNZu9pEmR7yR3s=";
  };

  buildInputs =
    [
      flac
      libmad
      libvorbis
      mpg123
    ]
    ++ optional pulseSupport libpulseaudio
    ++ optional alsaSupport alsa-lib
    ++ optional portaudioSupport portaudio
    ++ optionals stdenv.hostPlatform.isDarwin [
      appleSdkPackages.CoreVideo
      appleSdkPackages.VideoDecodeAcceleration
      appleSdkPackages.CoreAudio
      appleSdkPackages.AudioToolbox
      appleSdkPackages.AudioUnit
      appleSdkPackages.Carbon
    ]
    ++ optional faad2Support faad2
    ++ optional ffmpegSupport ffmpeg
    ++ optional opusSupport opusfile
    ++ optional resampleSupport soxr
    ++ optional sslSupport openssl
    ++ optional (stdenv.hostPlatform.isAarch32 or stdenv.hostPlatform.isAarch64) libgpiod;

  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace opus.c \
      --replace "<opusfile.h>" "<opus/opusfile.h>"
  '';

  EXECUTABLE = binName;

  OPTS =
    [
      "-DLINKALL"
      "-DGPIO"
    ]
    ++ optional dsdSupport "-DDSD"
    ++ optional (!faad2Support) "-DNO_FAAD"
    ++ optional ffmpegSupport "-DFFMPEG"
    ++ optional opusSupport "-DOPUS"
    ++ optional portaudioSupport "-DPORTAUDIO"
    ++ optional pulseSupport "-DPULSEAUDIO"
    ++ optional resampleSupport "-DRESAMPLE"
    ++ optional sslSupport "-DUSE_SSL"
    ++ optional (stdenv.hostPlatform.isAarch32 or stdenv.hostPlatform.isAarch64) "-DRPI";

  env = lib.optionalAttrs stdenv.hostPlatform.isDarwin { LDADD = "-lportaudio -lpthread"; };

  installPhase = ''
    runHook preInstall

    install -Dm555 -t $out/bin                   ${binName}
    install -Dm444 -t $out/share/man/man1 doc/squeezelite.1

    runHook postInstall
  '';

  passthru = {
    inherit (slimserver) tests;
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Lightweight headless squeezebox client emulator";
    homepage = "https://github.com/ralph-irving/squeezelite";
    license = with licenses; [ gpl3Plus ] ++ optional dsdSupport bsd2;
    mainProgram = binName;
    maintainers = with maintainers; [ adamcstephens ];
    platforms =
      platforms.linux ++ lib.optionals (!alsaSupport && !pulseSupport) [ platforms.darwin ];
  };
}
