# flattoo-looks: whole-desktop presets (flattoo-look), window layouts
# (flattoo-layout), the i3 session config, generated wallpapers, and the
# lock/unlock that bakes the artist's choices into the NixOS config.
{
  lib,
  stdenv,
  python3,
  makeWrapper,
  xfce4-panel-profiles,
  xfconf,
  wmctrl,
  xdotool,
  xprop,
  zenity,
  libnotify,
  feh,
  git,
  nixos-rebuild,
  nix,
  coreutils,
  gnused,
  gnugrep,
  systemd,
  polkit,
  i3,
  xvfb-run,
  rofi,
  glib, # gio: trusted desktop launchers
  xrandr,
  xfdesktop,
  runCommand,
  dbus,
  xfce4-panel,
  xfce4-pulseaudio-plugin,
  xfce4-whiskermenu-plugin,
  xfce4-power-manager,
  xfce4-docklike-plugin,
}:
let
  py = python3.withPackages (
    ps: with ps; [
      pillow
      numpy
    ]
  );
  runtimePath = lib.makeBinPath [
    xfce4-panel-profiles
    xfconf
    wmctrl
    xdotool
    xprop
    zenity
    libnotify
    feh
    git
    nixos-rebuild
    nix
    coreutils
    gnused
    gnugrep
    systemd
    polkit
    rofi
    glib
    xrandr
    xfdesktop
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "flattoo-looks";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [
    makeWrapper
    py
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/flattoo/looks $out/share/flattoo/layouts $out/share/flattoo/i3 \
             $out/share/flattoo/rofi $out/share/flattoo/touchegg \
             $out/share/backgrounds/flattoo $out/share/applications $out/share/polkit-1/actions

    cp share/looks/*.json $out/share/flattoo/looks/
    cp share/layouts/*.json $out/share/flattoo/layouts/
    cp share/applications/*.desktop $out/share/applications/
    cp share/polkit-1/actions/*.policy $out/share/polkit-1/actions/
    cp share/rofi/*.rasi $out/share/flattoo/rofi/
    cp share/touchegg/touchegg.conf $out/share/flattoo/touchegg/
    install -m755 bin/flattoo-apps $out/bin/flattoo-apps
    substituteInPlace $out/bin/flattoo-apps --replace-fail '@rofi@' "$out/share/flattoo/rofi"
    patchShebangs $out/bin/flattoo-apps
    wrapProgram $out/bin/flattoo-apps --prefix PATH : ${lib.makeBinPath [ rofi ]}

    python3 wallpapers/make.py $out/share/backgrounds/flattoo 2560 1600

    sed -e "s|@wallpaper@|$out/share/backgrounds/flattoo/slate.png|" share/i3/config > $out/share/flattoo/i3/config
    cp share/i3/i3status.conf $out/share/flattoo/i3/

    for tool in flattoo-look flattoo-layout; do
      install -m755 bin/$tool $out/bin/$tool
      substituteInPlace $out/bin/$tool \
        --replace-quiet '@presets@' "$out/share/flattoo/''${tool#flattoo-}s" \
        --replace-quiet '@wallpapers@' "$out/share/backgrounds/flattoo"
      sed -i "1s|.*|#!${py}/bin/python3|" $out/bin/$tool
      wrapProgram $out/bin/$tool --prefix PATH : $out/bin:${runtimePath}
    done
    for tool in flattoo-lock flattoo-lock-apply flattoo-unlock flattoo-unlock-apply; do
      install -m755 bin/$tool $out/bin/$tool
      patchShebangs $out/bin/$tool
      wrapProgram $out/bin/$tool --prefix PATH : $out/bin:${runtimePath}
    done
    runHook postInstall
  '';

  passthru.tests = {
    # Every look preset must turn into a loadable panel profile; every layout
    # must validate; export/restore must round-trip a fake ~/.config.
    presets =
      runCommand "flattoo-looks-presets"
        {
          nativeBuildInputs = [
            finalAttrs.finalPackage
            py
            rofi
          ];
        }
        ''
          export HOME=$TMPDIR
          cd $TMPDIR
          for l in ${finalAttrs.finalPackage}/share/flattoo/looks/*.json; do
            n=$(basename $l .json)
            flattoo-look panel-tar $n $n.tar.bz2 >/dev/null
            python3 - $n.tar.bz2 <<'PY'
          import sys, tarfile, re
          t = tarfile.open(sys.argv[1])
          names = t.getnames()
          assert "config.txt" in names, names
          cfg = t.extractfile("config.txt").read().decode()
          props = dict(l.split(" ", 1) for l in cfg.splitlines() if l.strip())
          panels = re.findall(r"<(\d+)>", props["/panels"])
          assert panels and panels[0] == "1", props["/panels"]
          seen = set()
          for n in panels:
              assert re.fullmatch(r"'p=(1|5|6|9|10|11|12);x=0;y=0'", props[f"/panels/panel-{n}/position"]), props[f"/panels/panel-{n}/position"]
              ids = re.findall(r"<(\d+)>", props[f"/panels/panel-{n}/plugin-ids"])
              assert ids and not (set(ids) & seen), ids
              seen |= set(ids)
              for i in ids:
                  assert f"/plugins/plugin-{i}" in props, i
                  if props[f"/plugins/plugin-{i}"] == "'launcher'":
                      items = re.findall(r"'([^']+)'", props[f"/plugins/plugin-{i}/items"])
                      for d in items:
                          assert f"launcher-{i}/{d}" in names, (i, d)
          print(sys.argv[1], len(panels), "panels", len(seen), "plugins ok")
          PY
          done
          for l in ${finalAttrs.finalPackage}/share/flattoo/layouts/*.json; do
            flattoo-layout validate $l
          done
          flattoo-look list | grep -q "Studio Dark"
          flattoo-look list | grep -q "Home"
          # every look names a GTK theme, icon theme and cursor that ship with the system (checked in modules/looks.nix)
          python3 - ${finalAttrs.finalPackage}/share/flattoo/looks <<'PY'
          import json, os, sys
          d = sys.argv[1]
          for f in os.listdir(d):
              p = json.load(open(os.path.join(d, f)))
              for k in ("gtk_theme", "xfwm_theme", "icon_theme", "cursor_theme", "wallpaper", "title"):
                  assert p.get(k), (f, k)
              assert p.get("app_names") in ("familiar", "standard"), f
          PY
          # the app grid theme parses
          rofi -dump-theme -theme ${finalAttrs.finalPackage}/share/flattoo/rofi/apps.rasi >/dev/null
          flattoo-layout list | grep -q "Reference + Draw"

          # export / restore round trip
          mkdir -p $HOME/.config/xfce4/xfconf/xfce-perchannel-xml $HOME/.config/xfce4/panel/launcher-3 $HOME/.config/flattoo/layouts
          echo '<?xml version="1.0"?><channel name="xsettings" version="1.0"><property name="Net" type="empty"><property name="ThemeName" type="string" value="Arc-Dark"/></property></channel>' > $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
          echo '[Desktop Entry]' > $HOME/.config/xfce4/panel/launcher-3/krita.desktop
          echo '{"name":"mine","windows":[{"app":"krita"}]}' > $HOME/.config/flattoo/layouts/mine.json
          flattoo-look export $TMPDIR/bundle >/dev/null
          test -f $TMPDIR/bundle/xfce-perchannel-xml/xsettings.xml
          test -f $TMPDIR/bundle/panel/launcher-3/krita.desktop
          test -f $TMPDIR/bundle/config/flattoo/layouts/mine.json
          test -f $TMPDIR/bundle/MANIFEST
          export HOME=$TMPDIR/home2; mkdir -p $HOME
          flattoo-look restore-files $TMPDIR/bundle
          grep -q Arc-Dark $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
          test -f $HOME/.config/xfce4/panel/launcher-3/krita.desktop
          test -f $HOME/.config/flattoo/layouts/mine.json
          echo "ok: presets, layouts, export/restore"
          touch $out
        '';

    # Every preset's panel profile must load into a real xfce4-panel: xfconfd
    # + panel under Xvfb, xfce4-panel-profiles load, then the panels and
    # plugin ids the preset declares must exist and no "plugin could not be
    # loaded" dialog may be up. (A bare [0.9, ...] array once crashed xfconfd.)
    panelLoad =
      runCommand "flattoo-looks-panel-load"
        {
          nativeBuildInputs = [
            finalAttrs.finalPackage
            xvfb-run
            dbus
            xfconf
            xfce4-panel
            xfce4-panel-profiles
            xdotool
            py
          ];
          XDG_DATA_DIRS = lib.makeSearchPath "share" [
            xfce4-panel
            xfce4-pulseaudio-plugin
            xfce4-whiskermenu-plugin
            xfce4-power-manager
            xfce4-docklike-plugin
            finalAttrs.finalPackage
          ];
        }
        ''
          export HOME=$TMPDIR/home XDG_CONFIG_HOME=$TMPDIR/home/.config XDG_CACHE_HOME=$TMPDIR/home/.cache XDG_RUNTIME_DIR=$TMPDIR/run
          mkdir -p $HOME/.config $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
          cd $TMPDIR
          xvfb-run -a -s "-screen 0 1280x800x24" dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf -- bash -e <<'SH'
            ${xfconf}/lib/xfce4/xfconf/xfconfd &
            sleep 2
            xfce4-panel --disable-wm-check >$TMPDIR/panel.log 2>&1 &
            sleep 5
            for l in ${finalAttrs.finalPackage}/share/flattoo/looks/*.json; do
              n=$(basename $l .json)
              flattoo-look panel-tar $n $n.tar.bz2 >/dev/null
              xfce4-panel-profiles load $n.tar.bz2
              sleep 6
              python3 - $l <<'PY'
          import json, subprocess, sys
          p = json.load(open(sys.argv[1]))
          want = len(p["panels"]) if "panels" in p else 1
          q = lambda prop: subprocess.run(["xfconf-query", "-c", "xfce4-panel", "-p", prop], capture_output=True, text=True).stdout
          panels = [l for l in q("/panels").splitlines() if l.strip().isdigit()]
          assert len(panels) == want, (p["name"], panels)
          for n in panels:
              ids = [l for l in q(f"/panels/panel-{n}/plugin-ids").splitlines() if l.strip().isdigit()]
              assert ids, (p["name"], n)
              assert q(f"/panels/panel-{n}/position").startswith("p="), (p["name"], n)
          print(p["name"], len(panels), "panel(s) loaded,", sum(1 for _ in panels), "ok")
          PY
              # the loader restarts the panel; give the new process time, start one if it is gone
              for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f xfce4-panel >/dev/null && break; sleep 2; done
              if ! pgrep -f xfce4-panel >/dev/null; then
                echo "$n: the panel did not come back; starting one"
                xfce4-panel --disable-wm-check >>$TMPDIR/panel.log 2>&1 &
              fi
              sleep 8
              if xdotool search --name "could not be loaded" >/dev/null 2>&1; then
                echo "$n: a plugin failed to load"; exit 1
              fi
            done
            pkill -f xfce4-panel || true
          SH
          touch $out
        '';

    # The i3 config must parse (i3 -C validates without a window manager
    # running, but needs an X display).
    i3config =
      runCommand "flattoo-looks-i3config"
        {
          nativeBuildInputs = [
            i3
            xvfb-run
          ];
        }
        ''
          export HOME=$TMPDIR
          xvfb-run -a i3 -C -c ${finalAttrs.finalPackage}/share/flattoo/i3/config 2>&1 | tee check.log
          ! grep -qiE "error|unknown" check.log
          echo "ok: i3 config parses"
          touch $out
        '';
  };

  meta = {
    description = "Flattoo desktop looks, window layouts, i3 session and the setup lock";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "flattoo-look";
  };
})
