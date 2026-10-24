# Printing. Two queues matter in a studio: the stencil printer (handled in
# stencil.nix) and whatever office printer is on the shop Wi-Fi.
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
  services.printing = {
    enable = true;
    # Local use only. cups-browsed (remote-queue auto-discovery daemon) stays
    # off: it has a CVE history and the GUI finds network printers without it.
    listenAddresses = [ "localhost:631" ];
    browsing = false;
    browsed.enable = false;
    drivers = [
      pkgs.brlaser
    ] # open driver for Brother office lasers
    ++ lib.optionals (cfg.stencil.enable && cfg.stencil.brother.enable) [
      pkgs.brother-pj723-cupswrapper
    ]
    ++ lib.optionals (cfg.stencil.enable && cfg.stencil.phomemo.enable) [
      (pkgs.phomemo-m08f.override { src = cfg.stencil.phomemo.driverArchive; })
    ];
    # The lpadmin group is created by the CUPS module; both users are in it,
    # so adding a printer never asks for a password.
  };

  # Brother's 32-bit option tool has /opt/brother/PTouch/pj723/inf/* compiled
  # in as a format string, too short to patch to a store path. A symlink at
  # that path is the whole fix; verified end to end against the PS->raster chain.
  systemd.tmpfiles.rules = lib.mkIf (cfg.stencil.enable && cfg.stencil.brother.enable) [
    "L+ /opt/brother/PTouch/pj723 - - - - ${pkgs.brother-pj723-lpr}/opt/brother/PTouch/pj723"
  ];

  # Print to PDF, lands in ~/PDF.
  services.printing.cups-pdf.enable = true;

  # Driverless printers (AirPrint / IPP Everywhere) over Wi-Fi and over USB.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true; # UDP 5353 only
  };
  services.ipp-usb.enable = true;

  programs.system-config-printer.enable = true;
}
