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
  xfce4-session, # xflock4, xfce4-session-logout (the power sheet)
  xfce4-screensaver, # the slideshow helper the shop display runs, xfce4-screensaver-command
  picom, # window effects
  redshift, # the warm screen of the night looks
  procps,
  util-linux, # flock
  shellcheck,
  league-gothic, # the wordmark on the boot splash
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
    xfce4-session
    xfce4-screensaver
    picom
    redshift
    procps
  ];
  slideshow = "${xfce4-screensaver}/libexec/xfce4-screensaver/slideshow";
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
             $out/share/backgrounds/flattoo $out/share/applications/screensavers $out/share/polkit-1/actions

    cp share/looks/*.json $out/share/flattoo/looks/
    cp share/layouts/*.json $out/share/flattoo/layouts/
    cp share/applications/*.desktop $out/share/applications/
    cp share/applications/screensavers/*.desktop $out/share/applications/screensavers/
    substituteInPlace $out/share/applications/screensavers/flattoo-showcase.desktop \
      --replace-fail 'Exec=flattoo-showcase slideshow' "Exec=$out/bin/flattoo-showcase slideshow" \
      --replace-fail 'TryExec=flattoo-showcase' "TryExec=$out/bin/flattoo-showcase"
    cp share/polkit-1/actions/*.policy $out/share/polkit-1/actions/
    cp share/rofi/*.rasi $out/share/flattoo/rofi/
    cp share/touchegg/touchegg.conf $out/share/flattoo/touchegg/
    for tool in flattoo-apps flattoo-power; do
      install -m755 bin/$tool $out/bin/$tool
      substituteInPlace $out/bin/$tool --replace-fail '@rofi@' "$out/share/flattoo/rofi"
      patchShebangs $out/bin/$tool
      wrapProgram $out/bin/$tool --prefix PATH : ${
        lib.makeBinPath [
          rofi
          xfce4-session
          xfce4-screensaver
          systemd
          procps
        ]
      }
    done
    install -m755 bin/flattoo-compositor $out/bin/flattoo-compositor
    patchShebangs $out/bin/flattoo-compositor
    wrapProgram $out/bin/flattoo-compositor --prefix PATH : ${
      lib.makeBinPath [
        picom
        xfconf
        procps
        coreutils
        util-linux
      ]
    }

    FLATTOO_FONT=${league-gothic}/share/fonts/truetype/LeagueGothic-Regular.ttf \
      python3 wallpapers/make.py $out/share/backgrounds/flattoo 2560 1600

    sed -e "s|@wallpaper@|$out/share/backgrounds/flattoo/slate.png|" share/i3/config > $out/share/flattoo/i3/config
    cp share/i3/i3status.conf $out/share/flattoo/i3/

    for tool in flattoo-look flattoo-layout flattoo-showcase; do
      install -m755 bin/$tool $out/bin/$tool
      substituteInPlace $out/bin/$tool \
        --replace-quiet '@presets@' "$out/share/flattoo/''${tool#flattoo-}s" \
        --replace-quiet '@wallpapers@' "$out/share/backgrounds/flattoo" \
        --replace-quiet '@slideshow@' "${slideshow}"
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
          src = ./.;
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
          python3 - ${finalAttrs.finalPackage}/share/flattoo/looks ${finalAttrs.finalPackage}/share/backgrounds/flattoo <<'PY'
          import json, os, sys
          d, wp = sys.argv[1], sys.argv[2]
          names = {f[:-5] for f in os.listdir(d)}
          effect_keys = {"corners", "shadows", "blur", "animations", "fade", "inactive_opacity", "shadow_opacity", "shadow_color"}
          palette_keys = {"bg", "fg", "muted", "accent", "on_accent", "border", "card", "rofi_bg", "radius"}
          positions = {"top-left", "bottom-left", "top-right", "bottom-right", "top-center", "bottom-center"}
          for f in os.listdir(d):
              p = json.load(open(os.path.join(d, f)))
              for k in ("gtk_theme", "xfwm_theme", "icon_theme", "cursor_theme", "wallpaper", "title", "palette", "notify"):
                  assert p.get(k), (f, k)
              assert p.get("app_names") in ("familiar", "standard"), f
              assert os.path.exists(os.path.join(wp, p["wallpaper"] + ".png")), (f, "wallpaper")
              e = p.get("effects", "missing")
              assert e is False or (isinstance(e, dict) and set(e) <= effect_keys), (f, "effects", e)
              assert set(p["palette"]) <= palette_keys, (f, "palette")
              assert p["notify"].get("position") in positions, (f, "notify")
              if "night" in p:
                  assert p["night"] in names and p["night"] != p["name"], (f, "night twin")
              if "night_light" in p:
                  assert 2500 <= int(p["night_light"]) <= 6500, (f, "night_light")
              assert p.get("keyboard", {}).get("<Super>Escape") == "flattoo-power", (f, "power sheet key")
          for must in ("flattoo-mark.png", "lockscreen.png"):
              assert os.path.exists(os.path.join(wp, must)), must
          print(len(names), "looks: effects, palette, notify, night twins ok")
          PY
          for l in ${finalAttrs.finalPackage}/share/flattoo/looks/*.json; do
            n=$(basename $l .json)
            flattoo-look picom-conf $n | grep -qE "^(rules = \(|# this look uses xfwm)"
            flattoo-look picom-conf $n --xrender | { ! grep -q dual_kawase; }
          done
          # the app grid and power sheet themes parse
          rofi -dump-theme -theme ${finalAttrs.finalPackage}/share/flattoo/rofi/apps.rasi >/dev/null
          rofi -dump-theme -theme ${finalAttrs.finalPackage}/share/flattoo/rofi/power.rasi >/dev/null
          flattoo-layout list | grep -q "Reference + Draw"

          # the automatic night look decides from the clock and the day look's twin (no display needed)
          mkdir -p $HOME/.config/flattoo
          echo home > $HOME/.config/flattoo/current-look
          flattoo-look schedule set 20:00 07:00 | grep -q "dark from 20:00 to 07:00"
          flattoo-look schedule tick --now 21:00 --dry-run | grep -qx "apply night:home-dark:"
          flattoo-look schedule tick --now 03:30 --dry-run | grep -qx "apply night:home-dark:"
          flattoo-look schedule tick --now 08:00 --dry-run | grep -qx "apply day:home:"
          echo gruvbox > $HOME/.config/flattoo/current-look
          python3 - <<'PY'
          import json, os
          p = os.path.expanduser("~/.config/flattoo/schedule.json")
          s = json.load(open(p)); s["day_look"] = "gruvbox"; json.dump(s, open(p, "w"))
          PY
          flattoo-look schedule tick --now 23:00 --dry-run | grep -qx "apply night::3800"   # no twin: warm screen only
          flattoo-look schedule set 22:30 6:15 | grep -q "22:30 to 06:15"
          flattoo-look schedule tick --now 22:00 --dry-run | grep -qx "apply day:gruvbox:"
          flattoo-look schedule off | grep -q off
          flattoo-look schedule tick --now 23:00 --dry-run | grep -qx off
          ! flattoo-look schedule set 25:00 07:00 2>/dev/null
          flattoo-look twin home dark | grep -qx home-dark
          flattoo-look twin home-dark light | grep -qx home
          flattoo-look twin sakura-night light | grep -qx sakura
          [ -z "$(flattoo-look twin neon dark)" ]
          flattoo-look current-name | grep -qx gruvbox
          echo "ok: automatic night look"

          # shop display: the newest gallery Portfolio built wins, a folder of pictures otherwise
          ! flattoo-showcase folder
          mkdir -p $HOME/Portfolio/2026-01-02/web $HOME/Portfolio/2026-03-04/web
          touch $HOME/Portfolio/2026-01-02/web/a.jpg
          flattoo-showcase folder | grep -q "2026-01-02/web"   # the newer build is empty, the older has pictures
          touch $HOME/Portfolio/2026-03-04/web/b.png
          flattoo-showcase folder | grep -q "2026-03-04/web"
          ${shellcheck}/bin/shellcheck -s bash $src/bin/flattoo-compositor $src/bin/flattoo-power $src/bin/flattoo-apps

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
            procps
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

    # Every look's generated picom config must start a real picom (both the
    # GL variant on Xvfb's software GLX and the xrender fallback) and keep
    # running; a bad rule or an unknown option makes picom exit at once.
    effects =
      runCommand "flattoo-looks-effects"
        {
          nativeBuildInputs = [
            finalAttrs.finalPackage
            xvfb-run
            picom
            procps
          ];
        }
        ''
          export HOME=$TMPDIR
          cd $TMPDIR
          xvfb-run -a -s "-screen 0 1280x800x24 +extension Composite +extension GLX" bash -e <<'SH'
            fail=0
            for l in ${finalAttrs.finalPackage}/share/flattoo/looks/*.json; do
              n=$(basename $l .json)
              flattoo-look picom-conf $n > $n.conf
              grep -q "xfwm's own compositor" $n.conf && { echo "$n: no picom (xfwm)"; continue; }
              flattoo-look picom-conf $n --xrender > $n-xrender.conf
              for variant in "$n.conf glx" "$n-xrender.conf xrender"; do
                set -- $variant
                picom --config $1 --backend $2 > $1.log 2>&1 &
                pid=$!
                sleep 3
                if kill -0 $pid 2>/dev/null; then
                  echo "$n: picom ok ($2)"; kill $pid; wait $pid 2>/dev/null || true
                elif [ $2 = glx ] && grep -q "No GLX extension" $1.log; then
                  echo "$n: no GLX on this X server, GL variant parsed only"   # Xvfb has none; the laptop does
                  continue
                else
                  echo "$n: picom DIED ($2)"; cat $1.log; fail=1
                fi
                if grep -iE "error|unknown|invalid|unrecognized" $1.log | grep -qv "No GLX extension"; then
                  echo "$n: picom complained ($2):"; grep -iE "error|unknown|invalid|unrecognized" $1.log; fail=1
                fi
              done
            done
            exit $fail
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
