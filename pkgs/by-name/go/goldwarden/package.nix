{ lib
, blueprint-compiler
, buildGoModule
, fetchFromGitHub
, gobject-introspection
, gtk4
, libadwaita
, libfido2
, libnotify
, python3
, wrapGAppsHook4
}:

buildGoModule rec {
  pname = "goldwarden";
  version = "0.3.4";

  src = fetchFromGitHub {
    owner = "quexten";
    repo = "goldwarden";
    rev = "v${version}";
    hash = "sha256-LAnhCQmyubWeZtTVaW8IoNmfipvMIlAnY4pKwrURPDs=";
  };

  postPatch = ''
    substituteInPlace gui/src/{linux/main.py,linux/monitors/dbus_monitor.py,gui/settings.py} \
      --replace-fail "python3" "${(python3.buildEnv.override { extraLibs = pythonPath; }).interpreter}"

    substituteInPlace gui/com.quexten.Goldwarden.desktop \
      --replace-fail "Exec=goldwarden_ui_main.py" "Exec=$out/bin/goldwarden-gui"

    substituteInPlace gui/src/gui/resources/commands.json \
      --replace-fail "flatpak run --filesystem=home --command=goldwarden com.quexten.Goldwarden" "goldwarden" \
      --replace-fail "flatpak run --command=goldwarden com.quexten.Goldwarden" "goldwarden" \
      --replace-fail 'SSH_AUTH_SOCK=/home/$USER/.var/app/com.quexten.Goldwarden/data/ssh-auth-sock' 'SSH_AUTH_SOCK=/home/$USER/.goldwarden-ssh-agent.sock'

    substituteInPlace cli/browserbiometrics/chrome-com.8bit.bitwarden.json cli/browserbiometrics/mozilla-com.8bit.bitwarden.json \
      --replace-fail "@PATH@" "$out/bin/goldwarden"
  '';

  vendorHash = "sha256-rMs7FP515aClzt9sjgIQHiYo5SYa2tDHrVRhtT+I8aM=";

  separateDebugInfo = true;

  nativeBuildInputs = [
    blueprint-compiler
    gobject-introspection
    python3.pkgs.wrapPython
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    libadwaita
    libfido2
    libnotify
  ];

  pythonPath = [
    python3.pkgs.dbus-python
    python3.pkgs.pygobject3
    python3.pkgs.tendo
  ];

  postInstall = ''
    blueprint-compiler batch-compile gui/src/gui/.templates/ gui/src/gui/ gui/src/gui/*.blp
    chmod +x gui/goldwarden_ui_main.py

    install -d "$out/share/goldwarden"
    cp -r -t "$out/share/goldwarden/" gui/*
    ln -s "$out/share/goldwarden/goldwarden_ui_main.py" "$out/bin/goldwarden-gui"
    rm "$out/share/goldwarden/"{com.quexten.Goldwarden.desktop,com.quexten.Goldwarden.metainfo.xml,goldwarden.svg,python3-requirements.json,requirements.txt}

    install -Dt "$out/share/applications" gui/com.quexten.Goldwarden.desktop
    install -Dt "$out/share/icons/hicolor/scalable/apps" gui/goldwarden.svg
    install -Dt "$out/share/metainfo" -m 644 gui/com.quexten.Goldwarden.metainfo.xml
    install -Dt "$out/share/polkit-1/actions" -m 644 cli/resources/com.quexten.goldwarden.policy

    install -Dm 755 cli/browserbiometrics/chrome-com.8bit.bitwarden.json "$out/etc/chrome/native-messaging-hosts/com.8bit.bitwarden.json"
    install -Dm 755 cli/browserbiometrics/chrome-com.8bit.bitwarden.json "$out/etc/chromium/native-messaging-hosts/com.8bit.bitwarden.json"
    install -Dm 755 cli/browserbiometrics/chrome-com.8bit.bitwarden.json "$out/etc/edge/native-messaging-hosts/com.8bit.bitwarden.json"
    install -Dm 755 cli/browserbiometrics/mozilla-com.8bit.bitwarden.json "$out/lib/mozilla/native-messaging-hosts/com.8bit.bitwarden.json"
  '';

  dontWrapGApps = true;
  postFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
    wrapPythonProgramsIn "$out/share/goldwarden" "$out/share/goldwarden $pythonPath"
  '';

  meta = {
    description = "Feature-packed Bitwarden compatible desktop integration";
    homepage = "https://github.com/quexten/goldwarden";
    license = lib.licenses.mit;
    mainProgram = "goldwarden";
    maintainers = [ lib.maintainers.arthsmn lib.maintainers.justanotherariel ];
    platforms = lib.platforms.linux; # Support for other platforms is not yet ready, see https://github.com/quexten/goldwarden/issues/4
  };
}
