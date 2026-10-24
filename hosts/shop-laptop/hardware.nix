# Generic laptop hardware. Enough initrd modules to boot any x86_64 laptop
# from NVMe, SATA or USB. flattoo-install adds a machine-specific
# hardware-configuration.nix next to this file; both are imported.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sdhci_pci"
    "rtsx_pci_sdmmc"
    "rtsx_usb_sdmmc"
    "uas"
  ];
  boot.kernelModules = [
    "kvm-intel"
    "kvm-amd"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Graphics: Mesa for Intel/AMD. Nvidia laptops need hardware.nvidia.*
  # in hardware-configuration.nix; the installer prints a note when it sees one.
  hardware.graphics.enable = true;
}
