{ stdenv, fetchFromGitHub
, mono
, imagemagick
}:

stdenv.mkDerivation rec {
  pname = "cito";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "pfusik";
    repo = "cito";
    # The `cito-0.4.0` tag is currently missing after leaving SourceForge.
    rev = "3ba21cf94b6f8101f419664dfeae9adc076699c8";
    sha256 = "1csjn7n33jvjsgi47q74agxmn713m4w3sm10y0h58c4zy93jhg42";
  };

  nativeBuildInputs = [ imagemagick ];
  buildInputs = [ mono ];

  postPatch = ''
    substituteInPlace Makefile --replace /usr/bin/mono ${mono}/bin/mono
  '';

  makeFlags = [ "prefix=$(out)" ];

  meta = with stdenv.lib; {
    description = "Translator from Ć to C, Java, C#, JavaScript, ActionScript, Perl and D";
    longDescription = ''
      cito automatically translates the Ć programming language to C, Java, C#,
      JavaScript, ActionScript, Perl and D. Ć is a new language, aimed at
      crafting portable programming libraries, with syntax akin to C#. The
      translated code is lightweight (no virtual machine, emulation nor large
      runtime), human-readable and fits well the target language (including
      naming conventions and documentation comments).
    '';
    homepage = https://github.com/pfusik/cito;
    license = licenses.gpl3;
    maintainers = with maintainers; [ bb010g ];
    platforms = with platforms; unix;
  };
}
