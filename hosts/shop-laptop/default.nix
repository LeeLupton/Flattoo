# The studio laptop. Everything here is a flattoo.* knob; the mechanics live
# in ../../modules.
{ lib, ... }:
{
  imports = [
    ../../modules
    ./disko.nix
    ./hardware.nix
  ]
  # Written by flattoo-install on the machine itself. Not in git: the
  # generic hardware.nix boots any x86_64 laptop, this one just adds the
  # exact modules and microcode nixos-generate-config detected.
  ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix
  # Also written by the installer: hashed passwords for the two accounts.
  # Not in git either. With users.mutableUsers = true, the GitHub version of
  # this flake leaves the passwords already on disk alone.
  ++ lib.optional (builtins.pathExists ./passwords.nix) ./passwords.nix;

  flattoo = {
    hostName = "studio";

    user = {
      name = "artist";
      fullName = "Artist";
    };
    admin = {
      name = "lee";
      sshKeys = [ ];
    };

    desktop = {
      autoLogin = true;
      lockOnSuspend = true;
    };

    # Set to true for Huion / XP-Pen / Gaomon tablets the kernel does not
    # drive on its own.
    tablet.openTabletDriver = false;

    stencil = {
      enable = true;
      brother.enable = true; # PocketJet 7: PJ-722/723/762/763/773 (S8 kit = PJ-723)
      phomemo.enable = true; # M08F family, TP8x; vendor archive pinned in pkgs/phomemo-cups
      density = 6;
    };

    extras.enable = false;

    remote = {
      tailscale.enable = false;
      ssh.enable = false;
    };

    autoUpgrade = {
      flake = "github:LeeLupton/Flattoo#shop-laptop";
      time = "03:30";
    };
  };
}
