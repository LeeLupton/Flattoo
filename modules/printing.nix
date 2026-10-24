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
  brotherOn = cfg.stencil.enable && cfg.stencil.brother.enable;
  phomemoOn = cfg.stencil.enable && cfg.stencil.phomemo.enable;
  phomemo =
    if cfg.stencil.phomemo.driverArchive == null then
      pkgs.phomemo-cups
    else
      pkgs.phomemo-cups.override { driverArchive = cfg.stencil.phomemo.driverArchive; };
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
      pkgs.brlaser # Brother office lasers
      pkgs.gutenprint # older Canon/Epson/HP inkjets and lasers
      pkgs.epson-escpr # Epson inkjets
      pkgs.hplip # HP printers and all-in-one scanners
    ]
    ++ lib.optionals brotherOn pkgs.brother-pj-cupswrappers # PJ-722/723/762/763/773
    ++ lib.optionals phomemoOn [ phomemo ]; # 75 Phomemo/QuYin models
    # The lpadmin group is created by the CUPS module; both users are in it,
    # so adding a printer never asks for a password.
  };

  # Brother's 32-bit option tool has /opt/brother/PTouch/<model>/inf/* compiled
  # in as a format string, too short to patch to a store path. A symlink at
  # that path is the whole fix; verified end to end against the PS->raster chain.
  systemd.tmpfiles.rules = lib.mkIf brotherOn (
    map (lpr: "L+ ${lpr.passthru.optPath} - - - - ${lpr}${lpr.passthru.optPath}") pkgs.brother-pj-lprs
  );

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
