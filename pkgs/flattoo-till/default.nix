# flattoo-till: "Money" — the feed of what is next and what is owed, a
# number pad that turns into a QR code the client pays, six-tap bookings,
# the consent form signed with a finger, the aftercare sheet, the ledger
# and its CSV for the accountant. Local only: the QR is a link into the
# artist's own payment app on the client's phone; the laptop records what
# the artist taps.
{
  lib,
  stdenv,
  python3,
  makeWrapper,
  wrapGAppsHook3,
  gobject-introspection,
  gtk3,
  pango,
  gdk-pixbuf,
  xdg-utils,
  cups,
  libnotify,
  xvfb-run,
  dejavu_fonts,
  adwaita-icon-theme,
  shellcheck,
  poppler-utils,
  makeFontsConf,
  runCommand,
}:
let
  py = python3.withPackages (
    ps: with ps; [
      pygobject3
      pycairo
      qrcode
      pillow
    ]
  );
  runtimePath = lib.makeBinPath [
    xdg-utils
    cups # lp
    libnotify
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "flattoo-till";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook3
    gobject-introspection
    py
  ];
  buildInputs = [
    gtk3
    pango
    gdk-pixbuf
  ];
  dontWrapGApps = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/flattoo/till $out/share/applications $out/share/icons/hicolor/scalable/apps
    cp share/flattoo/till/aftercare.txt $out/share/flattoo/till/
    cp share/applications/flattoo-till.desktop $out/share/applications/
    cp share/icons/hicolor/scalable/apps/flattoo-till.svg $out/share/icons/hicolor/scalable/apps/
    install -m755 bin/flattoo-till $out/bin/flattoo-till
    substituteInPlace $out/bin/flattoo-till --replace-fail '@share@' "$out/share/flattoo/till"
    sed -i "1s|.*|#!${py}/bin/python3|" $out/bin/flattoo-till
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/flattoo-till --prefix PATH : $out/bin:${runtimePath} "''${gappsWrapperArgs[@]}"
  '';

  passthru.tests = {
    offline =
      runCommand "flattoo-till-offline"
        {
          nativeBuildInputs = [
            finalAttrs.finalPackage
            py
            shellcheck
            poppler-utils # pdfinfo, pdftoppm: the PDFs must open and render
          ];
          FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ dejavu_fonts ]; };
        }
        ''
          shellcheck -s bash -e SC2016,SC2251,SC1010 ${./tests/till_test.sh} ${./tests/gui_test.sh}
          bash ${./tests/till_test.sh}
          touch $out
        '';
    gui =
      runCommand "flattoo-till-gui"
        {
          nativeBuildInputs = [
            finalAttrs.finalPackage
            py
            xvfb-run
          ];
          FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ dejavu_fonts ]; };
          XDG_DATA_DIRS = lib.makeSearchPath "share" [
            dejavu_fonts
            adwaita-icon-theme
            gtk3
          ];
        }
        ''
          bash ${./tests/gui_test.sh}
          mkdir -p $out
          cp $TMPDIR/*.png $out/
        '';
  };

  meta = {
    description = "Money: bookings, QR payments, consent forms, aftercare and the ledger for the studio laptop";
    license = {
      shortName = "FSAL-1.0";
      fullName = "Flattoo Source-Available License 1.0";
      url = "https://github.com/LeeLupton/Flattoo/blob/main/LICENSE";
      free = false;
      redistributable = true;
    };
    platforms = lib.platforms.linux;
    mainProgram = "flattoo-till";
  };
})
