{ stdenv, lib, fetchFromGitHub
, dotnet-netcore
, Nuget, dotnet-sdk, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "cito-unstable";
  version = "2020-02-21";

  src = fetchFromGitHub {
    owner = "pfusik";
    repo = "cito";
    rev = "2dcd11707bc7a0a38f2bdcf7f239cdccada3ef75";
    sha256 = "04mrrnyhlsw0sgnzdzh0xrizjsm47455s4nvljd8154np8hv0vjr";
  };
  patches = [
    ./make-dotnet.patch
  ];

  # Target framework (declared at top-level) pulled from "$src/cito.csproj".
  nativeBuildInputs = [ Nuget dotnet-sdk makeWrapper ];
  nativeCheckInputs = [ ];

  # Stripping breaks "$out/lib/cito/cito.dll".
  #
  # Changes noted by pedump (thanks, diffoscope!) were:
  #   COFF Header [COFF File Header]:
  #     Timestamp [TimeDateStamp]: [build timestamp] -> [0x00000000]
  #     Characteristics: 0x0022 -> 0x022e
  #       Per https://docs.microsoft.com/en-us/windows/win32/debug/pe-format
  #       this is a change of:
  #         IMAGE_FILE_EXECUTABLE_IMAGE     | 0x0002
  #       + IMAGE_FILE_LINE_NUMS_STRIPPED   | 0x0004
  #       + IMAGE_FILE_LOCAL_SYMS_STRIPPED  | 0x0008
  #         IMAGE_FILE_LARGE_ADDRESS_ AWARE | 0x0020
  #       + IMAGE_FILE_DEBUG_STRIPPED       | 0x0200
  #   PE Header [Optional Header Standard Fields]:
  #     LMajor [MajorLinkerVersion] (6): 0x30 -> 0x02
  #     LMinor [MinorLinkerVersion] (0): 0x00 -> 0x1f
  #   NT Header [Optional Header Windows-Specific Fields]:
  #     Checksum [CheckSum] (0): 0x00000000 -> 0x0002f9b5
  #   Data directories (no first column means unnoted; thanks, hexdump):
  #     Name: .text
  #       Flags [Characteristics]: 0x6000_0020 -> 0x6050_0020
  #           code  | IMAGE_SCN_CNT_CODE             | 0x0000_0020
  #         +       | IMAGE_SCN_ALIGN_16BYTES        | 0x0050_0000
  #           exec  | IMAGE_SCN_MEM_EXECUTE          | 0x2000_0000
  #           read  | IMAGE_SCN_MEM_READ             | 0x4000_0000
  #     Name: .rsrc
  #       Flags [Characteristics]: 0x4000_0040 -> 0xc030_0040
  #           data  | IMAGE_SCN_CNT_INITIALIZED_DATA | 0x0000_0040
  #         +       | IMAGE_SCN_ALIGN_4BYTES         | 0x0030_0000
  #           read  | IMAGE_SCN_MEM_READ             | 0x4000_0000
  #         + write | IMAGE_SCN_MEM_WRITE            | 0x8000_0000
  #
  # So, I'm guessing the alignment characteristic changes aren't going over
  # well with dotnet? mono can run the DLL just fine.
  #
  # I don't know which strip flags, if any, fix this. Plus, nothing really
  # is stripped anyways! C:
  dontStrip = true;

  preConfigure = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

    # disable nuget's default source to avoid dependency downloads
    nuget sources Disable -Name "nuget.org"

    # work around dotnet-sdk_3_0 permissions bug
    # - https://github.com/NixOS/nixpkgs/pull/69392
    # - https://github.com/dotnet/core-setup/pull/8644
    # - https://github.com/dotnet/runtime/issues/3801
    export DOTNET_ROOT="$TMPDIR/.dotnet"
    mkdir -p "$DOTNET_ROOT"
    cp -r ${stdenv.lib.escapeShellArg dotnet-sdk}/* "$DOTNET_ROOT"
    chmod -R u+w "$DOTNET_ROOT"
  '';

  postConfigure = ''
    "$DOTNET_ROOT"/dotnet restore
  '';

  makeFlags = [
    "prefix=$(out)"
    "DOTNET_SDK=$(DOTNET_ROOT)/dotnet"
    "DOTNET=${dotnet-netcore}/dotnet"
    "DOTNETFLAGS=--no-restore"
  ];

  doCheck = false;
  checkTarget = "test";

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
