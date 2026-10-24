# The "basic functions no one thinks of with Windows": a browser that does
# not phone home, phone transfer, archive formats, screenshots.
{ pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    # Enterprise policies: no telemetry, no sponsored tiles, uBlock Origin
    # installed and pinned, PDFs open in the browser.
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxAccounts = false;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      EnableTrackingProtection = {
        Value = true;
        Locked = false;
        Cryptomining = true;
        Fingerprinting = true;
      };
      FirefoxHome = {
        SponsoredTopSites = false;
        SponsoredPocket = false;
        Snippets = false;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        SkipOnboarding = true;
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
      };
    };
  };

  # LocalSend listens on 53317; the only inbound ports this laptop opens are
  # that one and mDNS for printer discovery.
  networking.firewall = {
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };

  environment.systemPackages = with pkgs; [
    unrar-free
    p7zip
    ffmpeg-headless # convert client videos to a frame grab
  ];
}
