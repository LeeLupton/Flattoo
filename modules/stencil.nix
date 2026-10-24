# The stencil printer queue and the stencil-tools scripts.
#
# Plug the printer in and a CUPS queue named "Stencil" appears with the right
# driver and stencil defaults (Letter, no scaling, binary halftone). Nothing
# to click. Unplug and replug a different model and the queue follows it.
# If it ever does not, the menu has "Fix Stencil Printer", which re-runs the
# same detection with no password.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo.stencil;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.stencil-tools ];

    # udev: any USB printer-class interface appearing starts the detection
    # service once CUPS is up. The service decides whether it is a stencil
    # printer; unknown printers are left alone.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="07", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
      # Phomemo/QuYin units that enumerate as vendor-specific rather than printer class.
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{product}=="*M08*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{product}=="TP8*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{manufacturer}=="*Phomemo*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{manufacturer}=="*QuYin*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
    '';

    systemd.services.stencil-queue-setup = {
      description = "Create or re-point the Stencil CUPS queue for the attached stencil printer";
      after = [ "cups.service" ];
      wants = [ "cups.service" ];
      serviceConfig = {
        Type = "oneshot";
        # Give the CUPS usb backend (and ipp-usb) a moment to enumerate the new device.
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 4";
        ExecStart = "${pkgs.stencil-tools}/bin/stencil-queue-setup";
        Environment = "FLATTOO_DENSITY=${toString cfg.density}";
      };
      path = [
        pkgs.cups
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
        pkgs.coreutils
      ];
    };

    # Also run once at boot in case the printer was plugged in while off.
    systemd.timers.stencil-queue-setup-boot = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "45s";
        Unit = "stencil-queue-setup.service";
      };
    };

    # "Fix Stencil Printer" in the menu starts that unit as the artist.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "stencil-queue-setup.service" &&
            action.lookup("verb") == "start" &&
            subject.isInGroup("flattoo")) {
          return polkit.Result.YES;
        }
      });
    '';

    # Session helper: HiDPI scaling on first login, tablet-to-screen mapping
    # whenever a pen device appears. Best effort; never touches settings the
    # artist has changed.
    environment.etc."xdg/autostart/flattoo-session.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Flattoo session helper
      Comment=Screen scaling and tablet mapping
      Exec=${pkgs.stencil-tools}/bin/flattoo-session
      OnlyShowIn=XFCE;
      NoDisplay=true
      X-GNOME-Autostart-Phase=Applications
    '';
  };
}
