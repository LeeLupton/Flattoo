# Customizability: themes, icons, cursors, fonts, whole-desktop looks,
# window layouts, and an optional i3 tiling session. Everything the artist
# can change from the menu; flattoo-lock later freezes what they chose.
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
  environment.systemPackages =
    with pkgs;
    [
      flattoo-looks
      xfce4-panel-profiles
      wmctrl
      xdotool
      xprop
      feh
      lxappearance # fine-tune GTK theme/icons/cursor by hand

      xfce4-docklike-plugin # the dock in the Home looks
      rofi # the app grid (flattoo-apps)

      # GTK + xfwm4 themes
      whitesur-gtk-theme # phone/Mac-style, the Home looks
      fluent-gtk-theme # Windows-style, Classic Desktop
      arc-theme
      materia-theme
      dracula-theme
      nordic
      gruvbox-gtk-theme
      adw-gtk3
      orchis-theme
      # icons
      whitesur-icon-theme
      fluent-icon-theme
      papirus-icon-theme
      tela-icon-theme
      numix-icon-theme
      adwaita-icon-theme
      # cursors
      whitesur-cursors
      bibata-cursors
      capitaine-cursors
      phinger-cursors
    ]
    ++ lib.optionals cfg.desktop.i3Session [
      i3status
      i3lock
    ]
    ++ lib.optional cfg.desktop.gestures touchegg;

  fonts.packages = with pkgs; [
    inter
    roboto
    lato
    montserrat
    work-sans
    jetbrains-mono
    # lettering: script, blackletter-ish, display, old style
    league-of-moveable-type # League Script, Blackout, Goudy Bookletter, Knewave, League Gothic…
    tex-gyre.chorus # Zapf Chancery clone, the classic script face
    tex-gyre.bonum
    tex-gyre.schola
    cinzel
    oldstandard
    eb-garamond
    libertinus
    junicode
    vollkorn
    crimson
    yanone-kaffeesatz
    league-gothic
    oswald
    source-serif
    ibm-plex
    comic-neue
  ];

  # The look applied at first login (marker in ~/.config/flattoo). Waits for
  # the panel so the panel profile lands on a running panel.
  environment.etc."flattoo/default-look".text = cfg.look.default;
  environment.etc."xdg/autostart/flattoo-look-seed.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Flattoo first-login look
    Exec=${pkgs.writeShellScript "flattoo-look-seed" ''
      cfgdir="''${XDG_CONFIG_HOME:-$HOME/.config}"
      marker="$cfgdir/flattoo/look-seeded"
      if [ ! -e "$cfgdir/touchegg/touchegg.conf" ]; then
        mkdir -p "$cfgdir/touchegg"
        cp ${pkgs.flattoo-looks}/share/flattoo/touchegg/touchegg.conf "$cfgdir/touchegg/"
      fi
      [ -e "$marker" ] && exit 0
      [ -e /etc/flattoo/locked ] && exit 0
      mkdir -p "$(dirname "$marker")"
      for _ in $(seq 1 60); do
        ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f xfce4-panel >/dev/null && break
        sleep 1
      done
      sleep 3
      ${pkgs.flattoo-looks}/bin/flattoo-look apply "$(cat /etc/flattoo/default-look)" && touch "$marker"
    ''}
    OnlyShowIn=XFCE;
    NoDisplay=true
  '';

  # Touchpad gestures: three fingers switch workspaces and maximize/minimize,
  # four fingers show the desktop, pinch zooms. Config seeded per user above.
  services.touchegg.enable = cfg.desktop.gestures;
  environment.etc."xdg/autostart/flattoo-touchegg.desktop" = lib.mkIf cfg.desktop.gestures {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Touchpad gestures
      Exec=${pkgs.touchegg}/bin/touchegg
      OnlyShowIn=XFCE;
      NoDisplay=true
    '';
  };

  # i3 as a second session at the login screen. Same helpers, same apps.
  services.xserver.windowManager.i3 = lib.mkIf cfg.desktop.i3Session {
    enable = true;
    configFile = "${pkgs.flattoo-looks}/share/flattoo/i3/config";
    extraSessionCommands = ''
      export XDG_CURRENT_DESKTOP=i3
    '';
  };
  environment.etc."xdg/i3status/config" = lib.mkIf cfg.desktop.i3Session {
    source = "${pkgs.flattoo-looks}/share/flattoo/i3/i3status.conf";
  };
  services.displayManager.defaultSession = lib.mkDefault "xfce";
}
