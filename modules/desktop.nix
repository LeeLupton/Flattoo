# XFCE on X11. X11 is deliberate: tablet pressure, cursor warping and
# Krita's canvas behave the way artists expect; Wayland is still catching up.
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
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    desktopManager.xfce = {
      enable = true;
      enableScreensaver = cfg.desktop.lockOnSuspend;
    };
    displayManager.lightdm = {
      enable = true;
      greeters.gtk.enable = true;
    };
  };

  services.displayManager.autoLogin = lib.mkIf cfg.desktop.autoLogin {
    enable = true;
    user = cfg.user.name;
  };

  # Things XFCE ships that this laptop has no use for.
  environment.xfce.excludePackages = with pkgs; [
    parole # media player
    xfce4-dict
  ];

  # Networking, sound, Bluetooth --------------------------------------------
  networking.networkmanager.enable = true;
  programs.nm-applet.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # File manager plumbing: thumbnails, USB/MTP automount, archives --------
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
      thunar-media-tags-plugin
    ];
  };
  programs.xfconf.enable = true;
  services.gvfs.enable = true; # USB sticks, phones over MTP, network shares
  services.tumbler.enable = true; # thumbnails in Thunar
  services.udisks2.enable = true;

  # iPhone photos arrive as HEIC, Android as WebP/AVIF. Windows needs a paid
  # codec pack for the first one; here every image viewer just opens them.
  programs.gdk-pixbuf.modulePackages = with pkgs; [
    libheif
    webp-pixbuf-loader
    libavif
  ];

  # Fonts -------------------------------------------------------------------
  fonts = {
    fontDir.enable = true; # Krita and font-manager see every installed font
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      liberation_ttf # metric-compatible Arial/Times/Courier
      dejavu_fonts
      corefonts # Microsoft core fonts; client reference sheets from Word
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      monospace = [ "DejaVu Sans Mono" ];
    };
  };

  # Desktop utilities -------------------------------------------------------
  environment.systemPackages = with pkgs; [
    xfce4-whiskermenu-plugin
    xfce4-clipman-plugin # clipboard history
    xfce4-screenshooter
    xfce4-pulseaudio-plugin
    xarchiver # zip/7z/rar front end
    font-manager # install a script font by double-clicking it
    localsend # phone <-> laptop file transfer over Wi-Fi, no cloud
    zenity
    libnotify
    xdg-utils
  ];

  # XFCE defaults for first login: panel layout, screensaver behavior,
  # Thunar right-click actions. Users can change them; these are seeds.
  environment.etc = {
    "xdg/xfce4/panel/default.xml".source = ../files/xfce/panel-default.xml;
    "xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml".source =
      if cfg.desktop.lockOnSuspend then
        ../files/xfce/xfce4-screensaver-lock.xml
      else
        ../files/xfce/xfce4-screensaver-nolock.xml;
    "xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml".source =
      ../files/xfce/xfce4-power-manager.xml;
    "xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml".source = ../files/xfce/xsettings.xml;
    "xdg/xfce4/helpers.rc".text = ''
      FileManager=Thunar
      TerminalEmulator=xfce4-terminal
    '';
    "xdg/Thunar/uca.xml".source = ../files/thunar/uca.xml;
  };

  # Open images in the viewer, edit in Krita, print stencils via the tool.
  xdg.mime = {
    enable = true;
    defaultApplications = {
      "image/png" = "org.xfce.ristretto.desktop";
      "image/jpeg" = "org.xfce.ristretto.desktop";
      "image/webp" = "org.xfce.ristretto.desktop";
      "image/heif" = "org.xfce.ristretto.desktop";
      "image/heic" = "org.xfce.ristretto.desktop";
      "image/avif" = "org.xfce.ristretto.desktop";
      "application/pdf" = "firefox.desktop";
      "application/x-krita" = "org.kde.krita.desktop";
      "image/openraster" = "org.kde.krita.desktop";
      "image/svg+xml" = "org.inkscape.Inkscape.desktop";
    };
  };
}
