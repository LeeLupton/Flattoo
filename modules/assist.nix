# What the laptop offers to do for the artist's professional image, and the
# rules it keeps while doing it (docs/assist.md):
#
#   Portfolio        a gallery from finished-work photos found in the usual
#                    folders — web sizes, square crops, a contact sheet.
#                    Originals untouched, metadata (location!) stripped, nothing
#                    uploaded, the guide asks about client consent.
#   Artist Profile   name, studio, styles, certifications, links -> résumé,
#                    bio, press text. Written by the artist, kept locally.
#   Exposure         the free places a studio is listed, how stale each is.
#   Weekly nudge     a notification, Monday mid-morning: an expiring
#                    certification, a stale listing, enough new photos for a
#                    gallery. It says; it never does. No network, ever.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo.assist;
in
{
  options.flattoo.assist = {
    enable = lib.mkEnableOption "Portfolio, Artist Profile and the exposure checklist" // {
      default = true;
    };
    reminders = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Weekly notification with things worth a minute (certification expiry, stale listings, new photos). Never acts on its own.";
    };
    reminderTime = lib.mkOption {
      type = lib.types.str;
      default = "Mon 10:30";
      description = "systemd calendar time for the weekly nudge.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.flattoo-assist ];

    systemd.user.services.flattoo-assist-remind = lib.mkIf cfg.reminders {
      description = "Flattoo weekly nudge (notification only)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.flattoo-assist}/bin/flattoo-profile remind";
        Nice = 15;
      };
    };
    systemd.user.timers.flattoo-assist-remind = lib.mkIf cfg.reminders {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.reminderTime;
        Persistent = true;
        RandomizedDelaySec = "15min";
      };
    };
  };
}
