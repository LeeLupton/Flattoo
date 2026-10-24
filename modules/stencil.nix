# The stencil printer queue and the stencil-tools scripts.
#
# Plug the printer in and a CUPS queue named "Stencil" appears with the right
# driver and stencil defaults (Letter, no scaling, binary halftone). Nothing
# to click. Unplug and replug a different model and the queue follows it.
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

    # udev: a Brother PJ or a Phomemo M08F-family printer appearing on USB
    # starts stencil-queue-setup.service once CUPS is up.
    services.udev.extraRules = ''
      # Brother PocketJet (PJ-7xx / PJ-8xx). Vendor 04f9.
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="04f9", ATTR{product}=="PJ-*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
      # Phomemo M08F family and its rebrands report the model in the product string.
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{product}=="*M08F*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{manufacturer}=="*Phomemo*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{manufacturer}=="*QuYin*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="stencil-queue-setup.service"
    '';

    systemd.services.stencil-queue-setup = {
      description = "Create or re-point the Stencil CUPS queue for the attached stencil printer";
      after = [ "cups.service" ];
      wants = [ "cups.service" ];
      serviceConfig = {
        Type = "oneshot";
        # Give the CUPS usb backend a moment to enumerate the new device.
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
  };
}
