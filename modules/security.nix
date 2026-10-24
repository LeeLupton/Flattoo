# Security posture for a shop laptop: encrypted disk, default-deny inbound,
# no remote listeners unless asked, kernel hardening that costs nothing.
{ lib, ... }:
{
  networking.firewall = {
    enable = true;
    # Default: nothing inbound. Modules open exactly what they need
    # (mDNS for printer discovery, LocalSend).
    allowPing = false;
    logRefusedConnections = false;
  };
  networking.nftables.enable = true;

  # NetworkManager: randomize MAC on scans and per-connection so the shop
  # Wi-Fi provider cannot build a movement profile from the laptop.
  networking.networkmanager.wifi.macAddress = "stable";
  networking.networkmanager.wifi.scanRandMacAddress = true;

  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.tcp_syncookies" = 1;
  };

  # Firewire/Thunderbolt DMA attacks: not plausible on a studio counter, but
  # the module is dead weight anyway.
  boot.blacklistedKernelModules = [
    "firewire-core"
    "firewire-ohci"
  ];

  # AppArmor confines the few network-facing daemons that ship profiles.
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = false;
  };

  # Polkit: the artist can mount drives, manage Wi-Fi and printers, and
  # suspend/shut down without a password. Everything else asks.
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("flattoo") && (
            action.id.indexOf("org.freedesktop.udisks2.") === 0 ||
            action.id.indexOf("org.freedesktop.NetworkManager.") === 0 ||
            action.id.indexOf("org.opensuse.cupspkhelper.") === 0 ||
            action.id === "org.freedesktop.login1.suspend" ||
            action.id === "org.freedesktop.login1.power-off" ||
            action.id === "org.freedesktop.login1.reboot" ||
            action.id.indexOf("org.freedesktop.fwupd.") === 0 ||
            action.id.indexOf("org.blueman.") === 0)) {
        return polkit.Result.YES;
      }
    });
  '';

  # No sshd, no avahi service publishing beyond printer discovery, no
  # cups remote admin. Those are all defaults in their modules; listed here
  # so the intent is in one place.
  services.openssh.enable = lib.mkDefault false;
  services.avahi.publish.enable = lib.mkDefault false;
}
