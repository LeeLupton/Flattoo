# Optional remote paths for the maintainer. Both off by default: the normal
# maintenance path is "push to the repo, laptop pulls tonight".
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
  config = lib.mkMerge [
    (lib.mkIf cfg.remote.tailscale.enable {
      services.tailscale = {
        enable = true;
        openFirewall = true;
        useRoutingFeatures = "client";
      };
      # MagicDNS through the local validating resolver (modules/network.nix
      # keeps NetworkManager and Tailscale out of resolv.conf).
      services.unbound.settings.forward-zone = lib.mkIf cfg.network.dns.enable [
        {
          name = "ts.net.";
          forward-addr = [ "100.100.100.100" ];
        }
      ];
      services.tailscale.extraUpFlags = [ "--accept-dns=false" ];
      # Only Tailscale may reach sshd when both are on.
      services.openssh.openFirewall = lib.mkIf cfg.remote.ssh.enable false;
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkIf cfg.remote.ssh.enable [ 22 ];
    })

    (lib.mkIf cfg.remote.ssh.enable {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [ cfg.admin.name ];
        };
      };
      assertions = [
        {
          assertion = cfg.admin.sshKeys != [ ];
          message = "flattoo.remote.ssh.enable needs at least one key in flattoo.admin.sshKeys";
        }
      ];
    })
  ];
}
