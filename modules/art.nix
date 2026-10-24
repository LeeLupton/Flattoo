# Drawing stack. Hand sketching first: scan, clean, trace, print.
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
  environment.systemPackages = with pkgs; [
    krita # primary: pressure, mirror tools, prints at 100%
    mypaint # pure sketching, infinite canvas
    inkscape # lettering and vector cleanup
    xournalpp # trace over a scanned sketch or a client photo
    gimp # installed, not on the panel
    simple-scan # scanner front end
    imagemagick # used by the stencil tools for HEIC/PDF/SVG input
  ];

  # Scanners: USB via SANE, Wi-Fi all-in-ones via AirScan/eSCL (driverless).
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  # Tablets ---------------------------------------------------------------
  # Default: kernel wacom driver + xf86-input-wacom. Covers Wacom and the
  # Huion/XP-Pen models the kernel's hid-uclogic driver knows.
  services.xserver.wacom.enable = !cfg.tablet.openTabletDriver;

  # Alternative: OpenTabletDriver for the rest of the Huion/XP-Pen/Gaomon
  # catalog. It blacklists the kernel drivers, so it is one or the other.
  hardware.opentabletdriver = lib.mkIf cfg.tablet.openTabletDriver {
    enable = true;
    daemon.enable = true;
  };

  # Monitor color profiles so what is on screen is what prints.
  services.colord.enable = true;
  systemd.user.services.xiccd = {
    description = "Apply colord display profiles on X11";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xiccd}/bin/xiccd";
      Restart = "on-failure";
    };
  };
}
