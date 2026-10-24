# Power and thermals for a laptop that lives on a studio counter.
{ lib, ... }:
{
  services.tlp = {
    enable = true;
    settings = {
      # Stop charging at 80% when it lives on the charger all day
      # (honored on ThinkPads and most ASUS/LG/Framework; ignored elsewhere).
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      # USB autosuspend breaks some tablets and thermal printers. Off.
      USB_AUTOSUSPEND = 0;
    };
  };
  services.power-profiles-daemon.enable = false; # conflicts with TLP
  services.thermald.enable = true; # Intel only; exits cleanly on AMD
  services.upower.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
  };

  # Touchpad: tap to click, natural scrolling, palm rejection while drawing.
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      disableWhileTyping = true;
    };
  };

  powerManagement.enable = true;
}
