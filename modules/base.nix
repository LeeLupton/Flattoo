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
  networking.hostName = cfg.hostName;
  time.timeZone = cfg.timeZone;

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Boot ------------------------------------------------------------------
  boot.loader.systemd-boot = {
    enable = true;
    # Every nightly upgrade adds an entry. Keep two weeks of rollbacks.
    configurationLimit = 14;
    # No kernel-command-line editing from the boot menu.
    editor = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;

  boot.kernelPackages = if cfg.kernel.latest then pkgs.linuxPackages_latest else pkgs.linuxPackages;

  # Quiet boot; the LUKS prompt is the only thing the artist sees.
  boot.kernelParams = [
    "quiet"
    "loglevel=3"
  ];
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;

  # Compressed RAM swap instead of a swap partition. No hibernation on this
  # machine; lid close = suspend.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;

  # Users -----------------------------------------------------------------
  users.mutableUsers = true; # passwords set at install time with chpasswd
  users.users.root.hashedPassword = "!"; # root login disabled; admin uses sudo

  users.groups.flattoo = { };

  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.fullName;
    extraGroups = [
      "flattoo"
      "networkmanager"
      "lp" # print
      "lpadmin" # add/remove printers without a password prompt
      "scanner"
      "video"
      "audio"
    ];
  };

  users.users.${cfg.admin.name} = {
    isNormalUser = true;
    description = "Maintainer";
    extraGroups = [
      "wheel"
      "flattoo"
      "networkmanager"
      "lp"
      "lpadmin"
      "scanner"
    ];
    openssh.authorizedKeys.keys = cfg.admin.sshKeys;
  };

  security.sudo.wheelNeedsPassword = true;

  # Nix -------------------------------------------------------------------
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # Only the official cache, only its key.
    substituters = [ "https://cache.nixos.org/" ];
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 21d";
  };
  nix.optimise.automatic = true;

  # Time sync, firmware updates, SSD trim.
  services.timesyncd.enable = true;
  services.fwupd.enable = true;
  services.fstrim.enable = true;

  # Tools a maintainer expects on any box. Nothing graphical here.
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    usbutils
    pciutils
    lshw
    file
    unzip
    _7zz
    wget
    curl
    rsync
    tree
    jq
  ];

  system.stateVersion = "26.05";
}
