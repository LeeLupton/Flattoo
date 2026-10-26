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

      # GTK + xfwm4 themes
      arc-theme
      materia-theme
      dracula-theme
      nordic
      gruvbox-gtk-theme
      adw-gtk3
      orchis-theme
      # icons
      papirus-icon-theme
      tela-icon-theme
      numix-icon-theme
      adwaita-icon-theme
      # cursors
      bibata-cursors
      capitaine-cursors
      phinger-cursors
    ]
    ++ lib.optionals cfg.desktop.i3Session [
      rofi
      i3status
      i3lock
    ];

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

  # The look applied at first login (marker in ~/.config/flattoo).
  environment.etc."flattoo/default-look".text = cfg.look.default;
  environment.etc."xdg/autostart/flattoo-look-seed.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Flattoo first-login look
    Exec=${pkgs.writeShellScript "flattoo-look-seed" ''
      marker="''${XDG_CONFIG_HOME:-$HOME/.config}/flattoo/look-seeded"
      [ -e "$marker" ] && exit 0
      [ -e /etc/flattoo/locked ] && exit 0
      mkdir -p "$(dirname "$marker")"
      sleep 3
      ${pkgs.flattoo-looks}/bin/flattoo-look apply "$(cat /etc/flattoo/default-look)" && touch "$marker"
    ''}
    OnlyShowIn=XFCE;
    NoDisplay=true
  '';

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
