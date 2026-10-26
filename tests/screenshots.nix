# Screenshots of the artist's desktop for the wiki, taken in a throwaway VM.
#
#   nix build .#screenshots          -> result/*.png + result/index.json
#   scripts/update-screenshots.sh    -> copies them into wiki/screenshots/
#
# The VM boots the real shop-laptop configuration (same modules, same looks,
# same apps) minus the disk layout, auto-logs the artist in, and the test
# script drives the desktop: every look preset, the menu, Ask Flattoo, the
# Looks / Layouts / Lock dialogs, the stencil tools' dialogs, two window
# layouts with the real apps, the lock screen, and the i3 session. Each
# screenshot's caption lives next to it in index.json so the wiki can place
# it without anyone editing paths by hand.
#
# Without KVM (CI, this sandbox) the VM runs under TCG: slow, but it works.
{
  pkgs,
  self,
  disko,
}:
let
  lib = pkgs.lib;
  looks = [
    "home"
    "home-dark"
    "studio-dark"
    "paper"
    "night-session"
    "big-and-simple"
    "classic-desktop"
    "gruvbox"
  ];
  lookCaptions = {
    home = "Home, the default look: app icons on the screen like a phone, a dock at the bottom, time and battery at the top. Files, Photos, Documents by their familiar names.";
    home-dark = "Home (dark): the same, for evening sessions.";
    studio-dark = "Studio Dark: dark grey, cool accents, panel on top. Easy on the eyes under studio lights.";
    paper = "Paper: light and warm, like the sketchbook.";
    night-session = "Night Session: near-black; the panel hides until the mouse touches the bottom edge.";
    big-and-simple = "Big and Simple: large text and icons, a dock with the four things that matter.";
    classic-desktop = "Classic Desktop: taskbar at the bottom, menu on the left, familiar names and icons. Feels like the last computer.";
    gruvbox = "Gruvbox: warm retro colors, panel on the left edge to keep the canvas wide.";
  };
  # A sample drawing for the Print as Stencil dialog.
  sample =
    pkgs.runCommand "flattoo-sample-drawing"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pillow ])) ];
      }
      ''
        python3 - <<'PY'
        from PIL import Image, ImageDraw
        import math
        W, H = 900, 1200
        im = Image.new("L", (W, H), 255)
        d = ImageDraw.Draw(im)
        cx, cy = W // 2, H // 2
        for k in range(12):
            a = k * math.pi / 6
            d.ellipse([cx - 320 + 120 * math.cos(a), cy - 320 + 120 * math.sin(a), cx + 320 + 120 * math.cos(a), cy + 320 + 120 * math.sin(a)], outline=0, width=6)
        d.ellipse([cx - 90, cy - 90, cx + 90, cy + 90], fill=0)
        im.save("sample-stencil.png", dpi=(300, 300))
        PY
        mkdir -p $out
        cp sample-stencil.png $out/
      '';

  common =
    { lib, pkgs, ... }:
    {
      imports = [
        ../hosts/shop-laptop
        disko.nixosModules.disko
      ];
      nixpkgs.overlays = [ self.overlays.default ];
      nixpkgs.config.allowUnfree = true;
      # The VM has its own disk; the laptop's LUKS/btrfs layout stays declared but inert.
      disko.enableConfig = false;
      flattoo.autoUpgrade.flake = lib.mkForce null;
      flattoo.network.dns.enable = false; # no internet in the VM
      # Where the laptop modules and the VM test harness disagree, the VM wins.
      services.timesyncd.enable = lib.mkForce false;
      users.users.artist.initialPassword = "artist";
      users.users.lee.initialPassword = "lee";
      users.users.root.hashedPassword = lib.mkForce null; # the test harness sets root's password itself
      boot.blacklistedKernelModules = [ "floppy" ]; # no "Floppy Disk" icon on the desktop
      environment.etc."flattoo/sample-stencil.png".source = "${sample}/sample-stencil.png";
      environment.systemPackages = [
        pkgs.xdotool
        pkgs.xset
      ];
      virtualisation = {
        memorySize = 3072;
        cores = 2;
        diskSize = 4096;
        resolution = {
          x = 1600;
          y = 900;
        };
      };
    };

  # Run as the artist inside the running session.
  asArtist = ''
    def artist(cmd, m=None, check=True):
        m = m or studio
        env = "export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus HOME=/home/artist FLATTOO_LAYOUT_WAIT=400; "
        full = "su artist -c " + repr(env + cmd)
        return m.succeed(full) if check else m.execute(full)

    def bg(cmd, m=None):
        artist(cmd + " >/dev/null 2>&1 &", m)

    def close_dialogs(m=None):
        m = m or studio
        m.execute("pkill -f 'flattoo-(copilot|look|layout|lock|wiki|portfolio|profile|apps)'; pkill -f 'stencil-(print|fix-printer|bt-setup|net-setup|calibrate)'; true")
        m.sleep(1)
        m.execute("pkill -f zenity; pkill -f rofi; true")
        artist("xdotool key Escape", m, check=False)
        m.sleep(1)

    captions = {}
    def shot(name, caption, m=None):
        m = m or studio
        artist("xdotool mousemove 5 5 mousemove 640 400", m, check=False)
        m.sleep(1)
        m.screenshot(name)
        captions[name] = caption

    def wait_window(pattern, m=None, timeout=300):
        """A window whose title matches pattern exists (zenity is slow to start under TCG)."""
        m = m or studio
        try:
            m.wait_until_succeeds("su artist -c 'DISPLAY=:0 xdotool search --name " + repr(pattern) + "'", timeout=timeout)
            m.sleep(4)
            return True
        except Exception:
            print(f"no window matching {pattern!r} after {timeout}s; taking the screenshot anyway")
            return False

    def wait_panel(m=None):
        m = m or studio
        m.wait_until_succeeds("pgrep -u artist -f xfce4-panel", timeout=600)
        m.sleep(25)

    def dump(m=None):
        m = m or studio
        for cmd in ["systemctl --no-pager status display-manager | tail -20",
                    "journalctl -b --no-pager -u display-manager | tail -30",
                    "journalctl -b --no-pager | grep -iE 'xfce|lightdm|flattoo|session' | tail -40",
                    "loginctl; ps -u artist -o pid,etime,cmd | head -40",
                    "tail -40 /home/artist/.xsession-errors 2>/dev/null; ls -la /home/artist/.config/flattoo 2>/dev/null"]:
            print("### " + cmd); print(m.execute(cmd)[1])

    def wait_desktop(m=None):
        """The XFCE session with its panel; the first-login look applied (or applied by us)."""
        m = m or studio
        try:
            m.wait_until_succeeds("pgrep -u artist -f xfce4-panel", timeout=2400)
        except Exception:
            dump(m); raise
        m.sleep(15)
        rc, _ = m.execute("timeout 600 bash -c 'until test -e /home/artist/.config/flattoo/look-seeded; do sleep 5; done'")
        if rc != 0:
            print("first-login seed did not finish; applying the default look directly")
            dump(m)
            artist("flattoo-look apply studio-dark", m)
            m.sleep(10)
  '';
in
pkgs.testers.runNixOSTest {
  name = "flattoo-screenshots";
  node.pkgsReadOnly = false;

  nodes.studio =
    { ... }:
    {
      imports = [ common ];
      # virtualisation.useNixStoreImage = true would read the closure from a
      # disk image instead of 9p (several times faster under TCG) but needs
      # the closure's size again as scratch space while the VM runs; 9p is
      # slow but needs nothing.
    };

  nodes.tiling =
    { lib, ... }:
    {
      imports = [ common ];
      services.displayManager.defaultSession = lib.mkForce "none+i3";
      # autologin into i3 instead of xfce
      services.displayManager.autoLogin.enable = true;
    };

  testScript = ''
    import json
    import os
    ${asArtist}

    studio.start()
    studio.wait_for_unit("graphical.target", timeout=2400)
    wait_desktop()
    studio.sleep(10)

    ${lib.concatMapStringsSep "\n" (l: ''
      artist("flattoo-look apply ${l}")
      wait_panel()
      shot("look-${l}", ${builtins.toJSON lookCaptions.${l}})
    '') looks}
    artist("flattoo-look apply home")
    wait_panel()

    # The app grid (Super key in the Home look)
    bg("flattoo-apps")
    wait_window("rofi")
    shot("apps-grid", "The Super key, or the grid button on the dock: every app as an icon. Type a few letters to filter.")
    close_dialogs()

    # Menu
    artist("flattoo-look apply studio-dark")
    wait_panel()
    bg("xfce4-popup-whiskermenu")
    wait_window("Whisker Menu")
    shot("menu", "The menu (top-left button, or the Super key): every app by category, search box at the top.")
    close_dialogs()

    # Ask Flattoo
    bg("flattoo-copilot")
    wait_window("Ask Flattoo")
    shot("ask-flattoo", "Ask Flattoo: type what you need in plain words.")
    close_dialogs()
    bg("flattoo-copilot 'something like paint'")
    wait_window("Ask Flattoo")
    shot("ask-flattoo-paint", "Ask Flattoo answering 'something like paint': the drawing apps that fit this laptop, Open or Install.")
    close_dialogs()

    # Looks, Layouts, Lock
    bg("flattoo-look gui")
    wait_window("Looks")
    shot("looks-gui", "Looks: pick a whole-desktop preset or save the current one.")
    close_dialogs()
    bg("flattoo-layout gui")
    wait_window("Layouts")
    shot("layouts-gui", "Layouts: open and arrange a set of windows in one click.")
    close_dialogs()
    bg("flattoo-lock")
    wait_window("Lock setup")
    shot("lock-dialog", "Lock This Setup: freezes the current desktop into the system. Unlock needs the administrator password.")
    close_dialogs()

    # Portfolio and Artist Profile
    bg("flattoo-portfolio")
    wait_window("Portfolio")
    shot("portfolio-dialog", "Portfolio: what it will do before it does anything — originals untouched, location data stripped, nothing uploaded, only clients who agreed.")
    close_dialogs()
    bg("flattoo-profile")
    wait_window("Artist Profile")
    shot("profile-dialog", "Artist Profile: the basics, skills, certifications, the résumé, the exposure checklist.")
    close_dialogs()

    # Stencil tools
    bg("stencil-print --gui /etc/flattoo/sample-stencil.png")
    wait_window("Print stencil")
    shot("print-stencil", "Print as Stencil with no stencil printer attached: it offers the other printers at true size instead. With the stencil printer on, it asks for width on skin, mirror, crisp lines or shading, copies.")
    close_dialogs()
    bg("stencil-fix-printer")
    wait_window("Stencil printer", timeout=480)
    shot("fix-printer", "Fix Stencil Printer: it looks over USB, Wi-Fi and Bluetooth and says what it found — here, with no printer attached, what you see when it finds nothing.")
    close_dialogs()
    bg("stencil-bt-setup")
    wait_window("Bluetooth stencil printer")
    shot("bluetooth-printer", "Add Bluetooth Stencil Printer, from the menu or Ask Flattoo. With the printer on and blinking, it lists it; pick it and type the PIN if asked.")
    close_dialogs()
    bg("stencil-net-setup")
    wait_window("Network stencil printer")
    shot("network-printer", "Add Network Stencil Printer: it sweeps the shop Wi-Fi for printers and lists what it finds, or takes an address.")
    close_dialogs()

    # File manager with the right-click actions
    studio.succeed("install -D -m644 /etc/flattoo/sample-stencil.png /home/artist/Pictures/rose-sketch.png; chown -R artist:users /home/artist/Pictures")
    bg("thunar /home/artist/Pictures")
    wait_window("Pictures")
    # click into the icon view (not the location bar), select the file, open its menu
    artist("xdotool search --name Pictures windowactivate --sync mousemove --window %1 420 420 click 1; sleep 1; xdotool key ctrl+a; sleep 2; xdotool key shift+F10", check=False)
    studio.sleep(6)
    shot("files-right-click", "Right-click an image in Files: Print as Stencil, Clean Lines, Open in Krita.")
    artist("xdotool key Escape", check=False)
    studio.execute("pkill -f thunar; true")
    studio.sleep(3)

    # Layouts with the real apps
    bg("flattoo-layout apply reference-and-draw")
    studio.wait_until_succeeds("su artist -c 'DISPLAY=:0 xdotool search --class krita'", timeout=900)
    studio.sleep(150)
    artist("flattoo-layout apply reference-and-draw", check=False)
    studio.sleep(10)
    shot("layout-reference-and-draw", "Reference + Draw: Krita on the left, the image viewer on the right for the reference.")
    studio.execute("pkill -f krita; pkill -f ristretto; true")
    studio.sleep(5)
    bg("flattoo-layout apply paperwork")
    studio.wait_until_succeeds("su artist -c 'DISPLAY=:0 xdotool search --class firefox'", timeout=900)
    studio.sleep(120)
    artist("flattoo-layout apply paperwork", check=False)
    studio.sleep(10)
    shot("layout-paperwork", "Paperwork: Firefox on the left, Files on the right.")
    studio.execute("pkill -f firefox; pkill -f thunar; true")
    studio.sleep(3)

    # Lock screen
    artist("pgrep -u $(id -u) -f xfce4-screensaver >/dev/null || (xfce4-screensaver >/dev/null 2>&1 &); sleep 8; xfce4-screensaver-command --lock", check=False)
    studio.sleep(15)
    artist("xset dpms force on; xset s reset; xdotool key shift; sleep 1; xdotool mousemove 300 300 mousemove 400 400 key shift", check=False)
    studio.sleep(6)
    shot("lock-screen", "The lock screen after the lid closes or ten idle minutes: the password is the disk passphrase unless the installer was told otherwise.")
    studio.send_chars("artist\n")
    studio.sleep(3)
    studio.shutdown()

    # i3 session
    tiling.start()
    tiling.wait_for_unit("graphical.target", timeout=2400)
    try:
        tiling.wait_until_succeeds("su artist -c 'DISPLAY=:0 xdotool search --class i3bar'", timeout=2400)
    except Exception:
        dump(tiling); raise
    tiling.sleep(40)
    shot("i3-desktop", "The i3 tiling session (pick it at the login screen): bar at the bottom, Super+D to launch, Super+Space for Ask Flattoo.", tiling)
    bg("flattoo-apps", tiling)
    wait_window("rofi", tiling)
    shot("i3-rofi", "Super+D in the i3 session: the same app grid, type the first letters of an app.", tiling)
    tiling.execute("pkill -f rofi; true")

    with open(f"{os.environ['out']}/index.json", "w") as f:
        json.dump([{"file": k + ".png", "caption": v} for k, v in captions.items()], f, indent=2)
  '';
}
