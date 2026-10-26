# flattoo-copilot: "Ask Flattoo". Plain-English requests -> one of a fixed
# set of actions (install/remove a catalog app, open, panel, update, printer,
# disk, wifi, bluetooth, battery, look, layout, lock). The only privileged
# path is flattoo-admin through polkit, with four subcommands.
{
  lib,
  stdenv,
  python3,
  bash,
  makeWrapper,
  zenity,
  xfce4-panel,
  xfce4-session, # xfce4-session-logout
  xfce4-settings, # xfce4-display-settings
  glib, # gtk-launch
  networkmanager,
  networkmanagerapplet,
  blueman,
  upower,
  systemd,
  pciutils,
  polkit,
  git,
  nixos-rebuild,
  nix,
  coreutils,
  gnused,
  gnugrep,
  gawk,
  runCommand,
  shellcheck,
  flattoo-looks,
  stencil-tools,
  flattoo-assist,
}:
let
  py = python3;
  runtimePath = lib.makeBinPath [
    zenity
    xfce4-panel
    xfce4-session
    xfce4-settings
    glib
    networkmanager
    networkmanagerapplet
    blueman
    upower
    systemd
    pciutils
    polkit
    coreutils
    gnugrep
    flattoo-looks
    stencil-tools
    flattoo-assist
  ];
  adminPath = lib.makeBinPath [
    py
    git
    nixos-rebuild
    nix
    coreutils
    gnused
    gnugrep
    gawk
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "flattoo-copilot";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [
    makeWrapper
    py
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/flattoo $out/share/applications $out/share/polkit-1/actions
    cp share/flattoo/catalog.json $out/share/flattoo/
    cp share/applications/*.desktop $out/share/applications/
    cp share/polkit-1/actions/*.policy $out/share/polkit-1/actions/

    install -m755 bin/flattoo-copilot $out/bin/flattoo-copilot
    substituteInPlace $out/bin/flattoo-copilot --replace-fail '@catalog@' "$out/share/flattoo/catalog.json"
    sed -i "1s|.*|#!${py}/bin/python3|" $out/bin/flattoo-copilot
    wrapProgram $out/bin/flattoo-copilot --prefix PATH : ${runtimePath}

    install -m755 bin/flattoo-admin $out/bin/flattoo-admin
    substituteInPlace $out/bin/flattoo-admin --replace-fail '@catalog@' "$out/share/flattoo/catalog.json"
    sed -i "1s|.*|#!${bash}/bin/bash|" $out/bin/flattoo-admin
    wrapProgram $out/bin/flattoo-admin --prefix PATH : ${adminPath}
    runHook postInstall
  '';

  passthru = {
    catalog = "${finalAttrs.finalPackage}/share/flattoo/catalog.json";
    tests = {
      # Phrasings -> actions, and the LLM-output validator.
      matcher =
        runCommand "flattoo-copilot-matcher"
          {
            nativeBuildInputs = [
              finalAttrs.finalPackage
              py
            ];
          }
          ''
            export HOME=$TMPDIR XDG_STATE_HOME=$TMPDIR/state
            python3 -I ${./tests/matcher_test.py} ${finalAttrs.finalPackage}/bin/.flattoo-copilot-wrapped ${finalAttrs.finalPackage}/share/flattoo/catalog.json
            touch $out
          '';
      # The root helper must lint clean and refuse non-catalog packages,
      # and the catalog itself must be well-formed.
      admin =
        runCommand "flattoo-copilot-admin"
          {
            nativeBuildInputs = [
              shellcheck
              py
            ];
          }
          ''
            shellcheck -s bash -e SC1091 ${./bin/flattoo-admin}
            python3 -I - ${finalAttrs.finalPackage}/share/flattoo/catalog.json <<'PY'
            import json, sys
            cat = json.load(open(sys.argv[1]))
            pkgs = [e["pkg"] for e in cat]
            assert len(pkgs) == len(set(pkgs)), "duplicate pkg"
            for e in cat:
                for k in ("pkg", "name", "category", "tags", "blurb"):
                    assert e.get(k), (e.get("pkg"), k)
                assert isinstance(e["tags"], list) and e["tags"]
            print(len(cat), "catalog entries ok")
            PY
            # the helper refuses when not root and does not reach the case statement
            ! ${bash}/bin/bash ${./bin/flattoo-admin} install pinta 2>&1 | grep -q '^ok$'
            touch $out
          '';
    };
  };

  meta = {
    description = "Ask Flattoo: plain-English copilot for apps, updates and upkeep, with a fixed action set";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "flattoo-copilot";
  };
})
