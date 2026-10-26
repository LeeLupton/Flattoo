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
    # -- drawing and painting
    krita # primary: pressure, mirror tools, prints at 100%
    mypaint # pure sketching, infinite canvas
    rnote # pen-first sketching and handwriting, infinite canvas, vector strokes
    azpainter # light painting app, fast on weak laptops, good tablet feel
    inkscape # lettering and vector cleanup; Trace Bitmap turns scans into clean paths
    xournalpp # trace over a scanned sketch or a client photo
    (gimp-with-plugins.override { plugins = [ gimpPlugins.gmic ]; }) # not on the panel; G'MIC brings line-art, stencil, engrave, posterize filters
    gmic-qt # G'MIC as a standalone app too
    drawing # the simplest possible paint app for a quick crop or arrow

    # -- stencil work beyond the right-click tools
    potrace # bitmap -> clean vector outlines
    autotrace # centerline tracing for single-line lettering
    gpick # pick a color off a reference photo

    # -- reference photos
    nomacs # zoom, compare side by side, basic adjust

    # -- in and out
    simple-scan # scanner front end
    imagemagick # used by the stencil tools for HEIC/PDF/SVG input
  ];

  # Scanners: USB via SANE, Wi-Fi all-in-ones via AirScan/eSCL (driverless).
  hardware.sane = {
    enable = true;
    extraBackends = [
      pkgs.sane-airscan
      pkgs.hplip
    ];
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
