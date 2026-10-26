# flattoo-assist: the things the laptop offers to do for the artist's
# professional image — a portfolio gallery from finished photos, a résumé
# and bio from a profile, the exposure checklist and a weekly nudge. All of
# it local: nothing is uploaded, looked up or posted.
{
  lib,
  stdenv,
  python3,
  makeWrapper,
  zenity,
  libnotify,
  xdg-utils,
  dejavu_fonts,
  runCommand,
}:
let
  py = python3.withPackages (
    ps: with ps; [
      pillow
      python-docx
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "flattoo-assist";
  version = "1.0.0";
  src = ./.;
  nativeBuildInputs = [
    makeWrapper
    py
  ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications
    cp share/applications/*.desktop $out/share/applications/
    for tool in flattoo-portfolio flattoo-profile; do
      install -m755 bin/$tool $out/bin/$tool
      sed -i "1s|.*|#!${py}/bin/python3|" $out/bin/$tool
      wrapProgram $out/bin/$tool \
        --prefix PATH : $out/bin:${
          lib.makeBinPath [
            zenity
            libnotify
            xdg-utils
          ]
        } \
        --prefix XDG_DATA_DIRS : ${dejavu_fonts}/share
    done
    runHook postInstall
  '';

  passthru.tests.offline =
    runCommand "flattoo-assist-offline"
      {
        nativeBuildInputs = [
          finalAttrs.finalPackage
          py
        ];
      }
      ''
        bash ${./tests/assist_test.sh}
        touch $out
      '';

  meta = {
    description = "Portfolio gallery, artist profile/résumé and exposure checklist for the studio laptop";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "flattoo-portfolio";
  };
})
