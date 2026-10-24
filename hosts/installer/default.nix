# Installer ISO. Boots to a console with Wi-Fi tools and one command:
# `flattoo-install`. The flake source is on the ISO at /etc/flattoo.
{
  config,
  lib,
  pkgs,
  modulesPath,
  self,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  image.baseName = lib.mkForce "flattoo-installer-${config.system.nixos.label}-x86_64";
  boot.zfs.forceImportRoot = false;

  isoImage = {
    volumeID = "FLATTOO";
    squashfsCompression = "zstd -Xcompression-level 6";
    appendToMenuLabel = " — Flattoo installer";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Wi-Fi during install: `nmtui`.
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  # The flake itself, read-only. flattoo-install copies it somewhere writable.
  environment.etc."flattoo".source = self;

  environment.systemPackages = with pkgs; [
    (import ./flattoo-install.nix { inherit pkgs; })
    disko
    git
    mkpasswd
    parted
    cryptsetup
    btrfs-progs
    pciutils
    usbutils
  ];

  services.getty.helpLine = lib.mkForce ''

    Flattoo installer.
      1. Wi-Fi:     nmtui
      2. Install:   sudo flattoo-install
  '';

  # No autologin fuss; the minimal ISO logs in as nixos.
  system.stateVersion = "26.05";
}
