# Without the keyboard. Some people will not type, ever; the laptop has to
# work for them with taps alone. The desktop already does (single-tap icons,
# the dock, the app grid, the power sheet, swipes). This module covers the
# places that still asked for keys:
#
#   * an on-screen keyboard (onboard) that pops up when any text field is
#     tapped and goes away again, with a Keyboard button on the panel,
#     and the same keyboard embedded in the lock screen and the login screen;
#   * a fingerprint reader for the lock screen and sudo (flattoo.desktop.fingerprint);
#   * a FIDO2 key for the disk passphrase (flattoo.disk.fido2): plug it in,
#     touch it, the laptop boots — the passphrase stays as the fallback.
#
# The boot passphrase and app-internal typing (file names, résumé text) are
# what remains; the copilot's own sheet and voice are in copilot.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.desktop.onScreenKeyboard {
      environment.systemPackages = [
        pkgs.onboard
        (pkgs.makeDesktopItem {
          name = "flattoo-keyboard";
          desktopName = "Keyboard";
          comment = "Show or hide the on-screen keyboard";
          icon = "input-keyboard";
          exec = "flattoo-keyboard";
          categories = [
            "Utility"
            "Accessibility"
            "X-Flattoo"
          ];
        })
        (pkgs.writeShellScriptBin "flattoo-keyboard" ''
          # Toggle the on-screen keyboard (the Keyboard button on the panel).
          if ${pkgs.dbus}/bin/dbus-send --session --print-reply --dest=org.onboard.Onboard \
               /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.ToggleVisible >/dev/null 2>&1; then
            exit 0
          fi
          exec ${pkgs.onboard}/bin/onboard
        '')
      ];

      # onboard's auto-show watches focus through the accessibility bus.
      services.gnome.at-spi2-core.enable = true;

      # Phone-style layout, docked at the bottom, shows itself when a text
      # field is tapped, hides on the first key of a real keyboard.
      programs.dconf.profiles.user.databases = [
        {
          settings = {
            "org/onboard" = {
              use-system-defaults = false;
              layout = "Phone";
              theme = "Nightshade";
              start-minimized = true;
              show-status-icon = false;
              xembed-onboard = true;
              system-theme-tracking-enabled = true;
            };
            "org/onboard/auto-show" = {
              enabled = true;
              hide-on-key-press = true;
              tablet-mode-detection-enabled = true;
            };
            "org/onboard/window" = {
              docking-enabled = true;
              force-to-top = true;
              window-state-sticky = true;
              transparent-background = false;
            };
            "org/onboard/window/landscape" = {
              dock-height = lib.gvariant.mkInt32 260;
            };
            "org/onboard/keyboard" = {
              show-click-buttons = false;
              audio-feedback-enabled = false;
            };
          };
        }
      ];

      environment.etc."xdg/autostart/flattoo-onboard.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=On-screen keyboard
        Exec=${pkgs.onboard}/bin/onboard
        OnlyShowIn=XFCE;
        NoDisplay=true
      '';

      # The login screen: the greeter's own keyboard button (it runs onboard --xid).
      services.xserver.displayManager.lightdm.greeters.slick.extraConfig =
        lib.mkIf cfg.desktop.loginScreen (lib.mkAfter "onscreen-keyboard=true\n");
      # The lock screen: xfce4-screensaver embeds the same keyboard (seed XML in files/xfce).
    })

    (lib.mkIf cfg.desktop.fingerprint {
      # Enrol once, as the maintainer: sudo fprintd-enroll artist
      # Then the lock screen, the login screen and sudo accept a finger;
      # the password keeps working.
      services.fprintd.enable = true;
    })

    (lib.mkIf cfg.disk.fido2 (
      let
        sd = config.boot.initrd.systemd.package;
      in
      {
        # Enrol once, as the maintainer, with the key plugged in:
        #   sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/disk-main-luks
        # From then on the boot splash waits ten seconds for a key (plug in,
        # touch) and asks for the passphrase only when none answers.
        boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [
          "fido2-device=auto"
          "token-timeout=10s"
        ];
        # systemd-cryptsetup's FIDO2 token plugin and the udev helper that
        # tags FIDO devices; stage 1 copies only what is listed.
        boot.initrd.systemd.storePaths = [
          "${sd}/lib/cryptsetup/libcryptsetup-token-systemd-fido2.so"
          "${sd}/lib/udev/fido_id"
        ];
        boot.initrd.services.udev.rules = ''
          SUBSYSTEM=="hidraw", IMPORT{program}="${sd}/lib/udev/fido_id"
          SUBSYSTEM=="hidraw", ENV{ID_FIDO_TOKEN}=="1", TAG+="security-device", TAG+="uaccess"
        '';
        boot.initrd.availableKernelModules = [
          "usbhid"
          "hid_generic"
        ];
        environment.systemPackages = [ pkgs.libfido2 ]; # fido2-token, for checking the key
      }
    ))
  ];
}
