# The lock. flattoo-lock captures the desktop into ./look and sets
# flattoo.locked = true in hosts/<host>/look.nix; this module turns that into:
#
#   bundle present  -> its xfconf channels are the system defaults
#   locked          -> bundle restored into the artist's config at every login,
#                      xfconf kiosk (panel/desktop/session changes need wheel),
#                      idle screen lock, Firefox add-ons frozen, boot menu
#                      hidden, nightly upgrades built from /etc/nixos with a
#                      weekly nixpkgs bump (so security fixes keep flowing
#                      without GitHub overwriting the local look).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo;
  bundle = cfg.look.bundle;
  xmlDir = if bundle == null then null else bundle + "/xfce-perchannel-xml";
  bundledChannels =
    if xmlDir != null && builtins.pathExists xmlDir then
      lib.filter (n: lib.hasSuffix ".xml" n) (builtins.attrNames (builtins.readDir xmlDir))
    else
      [ ];
  # Seeds for new accounts (desktop.nix sets a few of these too; the bundle wins).
  seeds = lib.listToAttrs (
    map (n: {
      name = "xdg/xfce4/xfconf/xfce-perchannel-xml/${n}";
      value = {
        source = lib.mkOverride 50 (xmlDir + "/${n}");
      };
    }) bundledChannels
  );
  restore = pkgs.writeShellScript "flattoo-restore-look" ''
    # Runs as the user before the session starts (xfconfd not up yet).
    [ "$(id -u)" -ge 1000 ] || exit 0
    ${pkgs.flattoo-looks}/bin/flattoo-look restore-files /etc/flattoo/look
    # Locked mode forces the idle lock whatever the captured screensaver settings say.
    f="''${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml"
    if [ -f "$f" ]; then
      ${pkgs.gnused}/bin/sed -i \
        -e '/name="saver"/,/<\/property>/ s|<property name="enabled" type="bool" value="false"/>|<property name="enabled" type="bool" value="true"/>|' \
        -e '/name="lock"/,/<\/property>/ s|<property name="enabled" type="bool" value="false"/>|<property name="enabled" type="bool" value="true"/>|' "$f"
    fi
  '';
in
{
  config = lib.mkMerge [
    {
      environment.etc."flattoo/host".text = cfg.flakeHost;
    }

    (lib.mkIf (bundle != null) (
      {
        environment.etc."flattoo/look".source = bundle;
        # A captured panel channel doubles as the first-login panel layout.
        environment.etc."xdg/xfce4/panel/default.xml" =
          lib.mkIf (builtins.elem "xfce4-panel.xml" bundledChannels)
            {
              source = lib.mkOverride 50 (xmlDir + "/xfce4-panel.xml");
            };
      }
      // {
        environment.etc = seeds;
      }
    ))

    (lib.mkIf cfg.locked {
      environment.etc."flattoo/locked".text = "locked\n";

      # Restore the captured desktop before every session.
      services.xserver.displayManager.sessionCommands = lib.mkIf (bundle != null) ''
        ${restore}
      '';

      # xfconf kiosk: only wheel may change panel, desktop, session settings.
      environment.etc."xdg/xfce4/kiosk/kioskrc".text = ''
        [xfce4-panel]
        CustomizePanel=%wheel

        [xfce4-session]
        CustomizeSplash=%wheel
        CustomizeChooser=%wheel
        CustomizeLogout=%wheel
        CustomizeCompatibility=%wheel
        CustomizeSecurity=%wheel
        SaveSession=%wheel
        Shutdown=ALL

        [xfdesktop]
        CustomizeBackdrop=%wheel
        CustomizeDesktopMenu=%wheel
        CustomizeWindowlist=%wheel
      '';

      # Idle lock after 10 minutes regardless of the captured settings.
      services.xserver.desktopManager.xfce.enableScreensaver = true;

      # Firefox: no new add-ons, no devtools.
      programs.firefox.policies = {
        ExtensionSettings."*" = {
          installation_mode = "blocked";
        };
        DisableDeveloperTools = true;
        BlockAboutConfig = true;
      };

      boot.loader.timeout = lib.mkForce 0;

      # Upgrades keep coming, from the local copy that holds the look.
      # flattoo-sync stops pulling the repo from GitHub (/etc/flattoo/locked);
      # only nixpkgs moves, once a week, so security fixes still land.
      system.autoUpgrade.flake = lib.mkForce "/etc/nixos#${cfg.flakeHost}";
      systemd.services.flattoo-nixpkgs-update = {
        description = "Weekly nixpkgs bump for the locked local flake";
        serviceConfig.Type = "oneshot";
        path = [
          pkgs.nix
          pkgs.git
          pkgs.coreutils
        ];
        script = ''
          cd /etc/nixos || exit 0
          nix --extra-experimental-features 'nix-command flakes' flake update nixpkgs
          if [ -d .git ]; then
            git -c user.name=flattoo-lock -c user.email=flattoo-lock@localhost add flake.lock
            git -c user.name=flattoo-lock -c user.email=flattoo-lock@localhost commit -q -m "flake.lock: weekly nixpkgs bump $(date -I)" || true
          fi
        '';
      };
      systemd.timers.flattoo-nixpkgs-update = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Mon 02:30";
          Persistent = true;
          RandomizedDelaySec = "20min";
        };
      };
    })
  ];
}
