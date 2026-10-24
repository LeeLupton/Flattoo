# Flattoo module set. Every knob the studio might need is a `flattoo.*` option
# so hosts/shop-laptop/default.nix stays a short, readable file.
{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  imports = [
    ./base.nix
    ./autoupgrade.nix
    ./desktop.nix
    ./art.nix
    ./printing.nix
    ./stencil.nix
    ./media.nix
    ./laptop.nix
    ./security.nix
    ./remote.nix
    ./extras.nix
  ];

  options.flattoo = {
    hostName = mkOption {
      type = types.str;
      default = "studio";
      description = "Machine hostname.";
    };

    user = {
      name = mkOption {
        type = types.str;
        default = "artist";
        description = "The tattoo artist's login. Auto-logged in, no sudo.";
      };
      fullName = mkOption {
        type = types.str;
        default = "Artist";
        description = "Display name shown on the login screen and in file dialogs.";
      };
    };

    admin = {
      name = mkOption {
        type = types.str;
        default = "lee";
        description = "Maintainer account with sudo. Used for in-person fixes.";
      };
      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "SSH public keys for the admin account (only used when flattoo.remote.ssh.enable is on).";
      };
    };

    timeZone = mkOption {
      type = types.str;
      default = "America/New_York";
    };

    kernel.latest = mkEnableOption "the latest mainline kernel instead of the LTS kernel (brand-new Wi-Fi or audio chipsets only)";

    desktop = {
      autoLogin = mkOption {
        type = types.bool;
        default = true;
        description = "Log the artist in automatically after the LUKS passphrase has gated the boot.";
      };
      lockOnSuspend = mkOption {
        type = types.bool;
        default = true;
        description = "Require the artist's password when the lid is reopened.";
      };
      darkPanel = mkOption {
        type = types.bool;
        default = true;
      };
    };

    tablet.openTabletDriver = mkEnableOption "OpenTabletDriver for Huion / XP-Pen / Gaomon tablets (replaces the kernel Wacom driver)";

    stencil = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Stencil printer queue, drivers and the stencil-tools scripts.";
      };
      brother.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Brother PocketJet 7 vendor drivers (PJ-722/723/762/763/773, the S8 stencil kit), fetched from download.brother.com at build time. PJ-8xx are driverless and need nothing.";
      };
      phomemo = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Phomemo / QuYin vendor driver: M08F family, TP81-TP88 stencil printers, T08FS and the label printers (75 PPDs).";
        };
        driverArchive = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Override the pinned vendor archive with a newer one from phomemo.com (zip, tar or .pet).";
        };
      };
      density = mkOption {
        type = types.ints.between 0 10;
        default = 6;
        description = "Brother PJ print density for the Stencil queue (0-10). Higher = more carbon transferred.";
      };
    };

    extras.enable = mkEnableOption "the optional AI helpers (upscaler, background remover). Off by default; nothing in the base image";

    remote = {
      tailscale.enable = mkEnableOption "Tailscale so the maintainer can reach the laptop from anywhere";
      ssh.enable = mkEnableOption "OpenSSH (key auth only, admin account only)";
    };

    autoUpgrade = {
      flake = mkOption {
        type = types.nullOr types.str;
        default = "github:LeeLupton/Flattoo#shop-laptop";
        description = ''
          Flake the laptop pulls every night. The new system becomes the boot
          default and takes effect at the next power-on; the running session is
          never touched. null disables nightly upgrades.
        '';
      };
      time = mkOption {
        type = types.str;
        default = "03:30";
        description = "systemd calendar time for the nightly pull. If the laptop was off, it runs after the next boot.";
      };
    };
  };
}
