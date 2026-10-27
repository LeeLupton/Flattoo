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
      # Always on: the shop display (portfolio slideshow when idle) and "Show
      # a client" run through it. Whether it LOCKS is the seed XML below.
      enableScreensaver = true;
    };
    displayManager.lightdm = {
      enable = true;
      # Auto-login skips the greeter; it still shows after a log-out, for the
      # maintainer account, and when a second session is picked. The slick
      # greeter is Mint's: big user tile, clock, session menu, on the ink
      # backdrop with the Flattoo mark.
      background = lib.mkIf cfg.desktop.loginScreen "${pkgs.flattoo-looks}/share/backgrounds/flattoo/lockscreen.png";
      greeters.gtk.enable = !cfg.desktop.loginScreen;
      greeters.slick = lib.mkIf cfg.desktop.loginScreen {
        enable = true;
        theme = {
          name = "WhiteSur-Dark";
          package = pkgs.whitesur-gtk-theme;
        };
        iconTheme = {
          name = "WhiteSur-dark";
          package = pkgs.whitesur-icon-theme;
        };
        cursorTheme = {
          name = "WhiteSur-cursors";
          package = pkgs.whitesur-cursors;
          size = 28;
        };
        font = {
          name = "Inter 12";
          package = pkgs.inter;
        };
        draw-user-backgrounds = false;
        extraConfig = ''
          show-hostname=false
          show-power=true
          show-a11y=false
          show-keyboard=false
          show-clock=true
          clock-format=%-I:%M %p
          activate-numlock=false
          draw-grid=false
          enable-hidpi=auto
        '';
      };
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
  programs.dconf.enable = true; # GTK4/libadwaita apps keep their settings here; looks set their dark/light mode through it
  services.gvfs.enable = true; # USB sticks, Android phones over MTP, network shares
  services.tumbler.enable = true; # thumbnails in Thunar
  services.udisks2.enable = true;

  # iPhone over a cable: usbmuxd pairs it, gvfs' AFC backend shows the photo
  # roll in Thunar after "Trust this computer" on the phone.
  services.usbmuxd.enable = true;

  # iPhone photos arrive as HEIC, Android as WebP/AVIF. Windows needs a paid
  # codec pack for the first one; here every image viewer just opens them.
  programs.gdk-pixbuf.modulePackages = with pkgs; [
    libheif.lib # the loader is in the lib output; the default (bin) has none
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
    libimobiledevice # iPhone pairing tools
    ifuse
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
