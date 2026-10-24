# Nightly pull from the Flattoo repo.
#
# How "secure automatic" works here:
#   1. GitHub Actions (.github/workflows/update-flake-lock.yml) bumps the
#      nixpkgs lock weekly, evaluates the laptop config, and only pushes to
#      main when evaluation succeeds.
#   2. The laptop pulls main at 03:30 (or after the next boot if it was off),
#      builds the new system and makes it the *boot default*. The running
#      session is untouched; the change lands at the next power-on.
#   3. If the new generation misbehaves, the previous one is one entry down
#      in the boot menu. Nothing is ever half-applied.
{ config, lib, ... }:
let
  cfg = config.flattoo.autoUpgrade;
in
{
  config = lib.mkIf (cfg.flake != null) {
    system.autoUpgrade = {
      enable = true;
      flake = cfg.flake;
      operation = "boot";
      dates = cfg.time;
      randomizedDelaySec = "45min";
      persistent = true;
      allowReboot = false;
      # Re-resolve the branch head instead of trusting the local flake cache.
      flags = [ "--refresh" ];
    };

    # Builds are background work. Keep the UI responsive if the laptop was
    # off at 03:30 and the timer fires during the day.
    systemd.services.nixos-upgrade.serviceConfig = {
      Nice = 15;
      IOSchedulingClass = "idle";
      CPUWeight = 20;
    };
  };
}
