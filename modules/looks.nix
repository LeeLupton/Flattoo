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
      rofi # the app grid, the power sheet
      redshift # the warm screen of the night looks

      # GTK + xfwm4 themes
      whitesur-gtk-theme # phone/Mac-style, the Home looks
      fluent-gtk-theme # Windows-style, Classic Desktop
      arc-theme
      materia-theme
      dracula-theme
      nordic
      gruvbox-gtk-theme # Gruvbox, Flash Sheet
      adw-gtk3
      orchis-theme
      graphite-gtk-theme # Blackwork
      tokyonight-gtk-theme # Neon
      rose-pine-gtk-theme # Sakura, Sakura Night
      everforest-gtk-theme # Forest
      kanagawa-gtk-theme # Kanagawa
      # icons
      whitesur-icon-theme
      fluent-icon-theme
      papirus-icon-theme
      tela-icon-theme
      numix-icon-theme
      adwaita-icon-theme
      qogir-icon-theme # Blackwork
      kora-icon-theme # Flash Sheet
      nordzy-icon-theme # Sakura, Neon, Forest, Kanagawa (one set, many colours)
      # cursors
      whitesur-cursors
      bibata-cursors
      capitaine-cursors
      phinger-cursors
      graphite-cursors
      rose-pine-cursor
      nordzy-cursor-theme
      volantes-cursors
    ]
    ++ lib.optional cfg.desktop.effects picom
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

  # Window effects: picom with the config the current look wrote, started
  # after the panel (so the dock's translucency is already there to blur
  # behind). The i3 session starts it from its own config.
  environment.etc."xdg/autostart/flattoo-compositor.desktop" = lib.mkIf cfg.desktop.effects {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Window effects
      Exec=${pkgs.writeShellScript "flattoo-compositor-start" ''
        for _ in $(seq 1 30); do
          ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f xfce4-panel >/dev/null && break
          sleep 1
        done
        sleep 2
        exec ${pkgs.flattoo-looks}/bin/flattoo-compositor start
      ''}
      OnlyShowIn=XFCE;
      NoDisplay=true
    '';
  };

  # The automatic night look: a tiny loop that checks the clock. Idle until
  # the artist turns it on (Looks → Automatic night look).
  environment.etc."xdg/autostart/flattoo-night-schedule.desktop" =
    lib.mkIf cfg.desktop.nightSchedule
      {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Automatic night look
          Exec=${pkgs.flattoo-looks}/bin/flattoo-look schedule daemon
          OnlyShowIn=XFCE;
          NoDisplay=true
        '';
      };

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
