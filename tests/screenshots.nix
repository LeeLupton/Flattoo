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
    "studio-dark"
    "paper"
    "night-session"
    "big-and-simple"
    "classic-desktop"
    "gruvbox"
  ];
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
      environment.etc."flattoo/sample-stencil.png".source = "${sample}/sample-stencil.png";
      environment.systemPackages = [ pkgs.xdotool ];
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
        m.execute("pkill -f 'flattoo-(copilot|look|layout|lock|wiki)'; pkill -f 'stencil-(print|fix-printer|bt-setup|net-setup|calibrate)'; true")
        m.sleep(1)
        m.execute("pkill -x zenity; pkill -x rofi; true")
        artist("xdotool key Escape", m, check=False)
        m.sleep(1)

    captions = {}
    def shot(name, caption, m=None):
        (m or studio).screenshot(name)
        captions[name] = caption

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
            m.wait_until_succeeds("pgrep -u artist -x xfce4-panel", timeout=2400)
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
      # Read the closure from a disk image instead of 9p: several times faster
      # under TCG. The image is built when the VM starts (about the closure's
      # size on disk, deleted with the sandbox).
      virtualisation.useNixStoreImage = true;
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
    shot("look-studio-dark", "Studio Dark, the default look: dark grey, panel on top with Ask Flattoo, Krita, MyPaint, Inkscape, files, scanner, calibration, LocalSend, Firefox.")

    ${lib.concatMapStringsSep "\n" (
      l:
      if l == "studio-dark" then
        ""
      else
        ''
          artist("flattoo-look apply ${l}")
          studio.sleep(8)
          shot("look-${l}", "The ${l} look, applied from Looks.")
        ''
    ) looks}
    artist("flattoo-look apply studio-dark")
    studio.sleep(8)

    # Menu
    bg("xfce4-popup-whiskermenu")
    studio.sleep(4)
    shot("menu", "The menu (top-left button, or the Super key): every app by category, search box at the top.")
    close_dialogs()

    # Ask Flattoo
    bg("flattoo-copilot")
    studio.sleep(5)
    shot("ask-flattoo", "Ask Flattoo: type what you need in plain words.")
    close_dialogs()
    bg("flattoo-copilot 'something like paint'")
    studio.sleep(8)
    shot("ask-flattoo-paint", "Ask Flattoo answering 'something like paint': the drawing apps that fit this laptop, Open or Install.")
    close_dialogs()

    # Looks, Layouts, Lock
    bg("flattoo-look gui")
    studio.sleep(5)
    shot("looks-gui", "Looks: pick a whole-desktop preset or save the current one.")
    close_dialogs()
    bg("flattoo-layout gui")
    studio.sleep(5)
    shot("layouts-gui", "Layouts: open and arrange a set of windows in one click.")
    close_dialogs()
    bg("flattoo-lock")
    studio.sleep(5)
    shot("lock-dialog", "Lock This Setup: freezes the current desktop into the system. Unlock needs the administrator password.")
    close_dialogs()

    # Stencil tools
    bg("stencil-print --gui /etc/flattoo/sample-stencil.png")
    studio.sleep(8)
    shot("print-stencil", "Print as Stencil (right-click any image): width on skin in inches, mirror, crisp lines or shading, copies.")
    close_dialogs()
    bg("stencil-fix-printer")
    studio.sleep(20)
    shot("fix-printer", "Fix Stencil Printer: it looks over USB, Wi-Fi and Bluetooth and says what it found — here, with no printer attached, what you see when it finds nothing.")
    close_dialogs()
    bg("stencil-bt-setup")
    studio.sleep(12)
    shot("bluetooth-printer", "Add Bluetooth Stencil Printer, from the menu or Ask Flattoo. With the printer on and blinking, it lists it; pick it and type the PIN if asked.")
    close_dialogs()
    bg("stencil-net-setup")
    studio.sleep(20)
    shot("network-printer", "Add Network Stencil Printer: it sweeps the shop Wi-Fi for printers and lists what it finds, or takes an address.")
    close_dialogs()

    # File manager with the right-click actions
    studio.succeed("install -D -m644 /etc/flattoo/sample-stencil.png /home/artist/Pictures/rose-sketch.png; chown -R artist:users /home/artist/Pictures")
    bg("thunar /home/artist/Pictures")
    studio.sleep(12)
    artist("xdotool search --sync --class Thunar windowactivate --sync key ctrl+a; sleep 1; xdotool key shift+F10", check=False)
    studio.sleep(3)
    shot("files-right-click", "Right-click an image in Files: Print as Stencil, Clean Lines, Open in Krita.")
    studio.execute("pkill -x thunar; true")
    studio.sleep(2)

    # Layouts with the real apps
    bg("flattoo-layout apply reference-and-draw")
    studio.wait_until_succeeds("su artist -c 'DISPLAY=:0 xdotool search --class krita'", timeout=900)
    studio.sleep(90)
    shot("layout-reference-and-draw", "Reference + Draw: Krita on the left, the image viewer on the right for the reference.")
    studio.execute("pkill -x krita; pkill -x ristretto; true")
    studio.sleep(5)
    bg("flattoo-layout apply paperwork")
    studio.wait_until_succeeds("su artist -c 'DISPLAY=:0 xdotool search --class firefox'", timeout=900)
    studio.sleep(60)
    shot("layout-paperwork", "Paperwork: Firefox on the left, Files on the right.")
    studio.execute("pkill -x firefox; pkill -x thunar; true")
    studio.sleep(3)

    # Lock screen
    artist("xflock4", check=False)
    studio.sleep(8)
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
    tiling.sleep(10)
    shot("i3-desktop", "The i3 tiling session (pick it at the login screen): bar at the bottom, Super+D to launch, Super+Space for Ask Flattoo.", tiling)
    bg("rofi -show drun -show-icons", tiling)
    tiling.sleep(5)
    shot("i3-rofi", "Super+D in the i3 session: type the first letters of an app.", tiling)
    tiling.execute("pkill -x rofi; true")

    with open(f"{os.environ['out']}/index.json", "w") as f:
        json.dump([{"file": k + ".png", "caption": v} for k, v in captions.items()], f, indent=2)
  '';
}
