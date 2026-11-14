# Money (docs/till.md): the part of the laptop that gets the artist paid,
# made as easy as scrolling a phone.
#
#   Feed       one card per thing that matters — the next client, a deposit
#              still owed, today's take, a client due to rebook — each with
#              one big button; swipe up for the next.
#   Get paid   number pad -> a QR code the client scans (Venmo, Cash App,
#              PayPal, Square, Zelle) with the amount filled in -> one tap
#              records it. Cash and card record too.
#   Book       client, what, when, price, deposit; the deposit code follows.
#   Papers     the consent form (finger signature, PDF, kept two years as
#              15A NCAC 18A .3206 asks) and the aftercare sheet.
#   Money      today / week / month / year, every payment, CSV for taxes.
#
# Rules it keeps: nothing leaves the laptop (the QR is a link into the
# artist's own payment app on the client's phone; there is no API, no
# account, no sync); a payment exists because the artist tapped Paid; the
# records are plain files under ~/Documents/Business the artist owns.
#
# The payment handles are the maintainer's job once (below) or the artist's
# under Money › Settings; the artist's own entries win.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo.till;
  inherit (lib) mkOption types;
  system = {
    currency = cfg.currency;
    pay = {
      inherit (cfg.payments)
        venmo
        cashapp
        paypal
        square
        zelle
        ;
    };
    review_link = cfg.reviewLink;
    booking_link = cfg.bookingLink;
    default_deposit = cfg.defaultDeposit;
    rebook_after_days = cfg.rebookAfterDays;
    hours = cfg.hours;
    printer = cfg.printer;
  };
in
{
  options.flattoo.till = {
    enable =
      lib.mkEnableOption "Money: bookings, QR payments, consent forms, aftercare, the ledger"
      // {
        default = true;
      };
    payments = {
      venmo = mkOption {
        type = types.str;
        default = "";
        description = "Venmo username (with or without @). The pay code opens Venmo with the amount filled in.";
      };
      cashapp = mkOption {
        type = types.str;
        default = "";
        description = "Cash App $cashtag.";
      };
      paypal = mkOption {
        type = types.str;
        default = "";
        description = "PayPal.me name.";
      };
      square = mkOption {
        type = types.str;
        default = "";
        description = "A Square checkout link (fixed; the client types the amount).";
      };
      zelle = mkOption {
        type = types.str;
        default = "";
        description = "Zelle phone number or e-mail. Zelle has no pay link; the code carries the number as text.";
      };
    };
    reviewLink = mkOption {
      type = types.str;
      default = "";
      description = "The studio's review link (Google: https://g.page/r/…/review). Shown as a QR card after the session.";
    };
    bookingLink = mkOption {
      type = types.str;
      default = "";
      description = "The booking page, as a QR card. Falls back to the booking link in the artist profile.";
    };
    currency = mkOption {
      type = types.str;
      default = "$";
    };
    defaultDeposit = mkOption {
      type = types.int;
      default = 50;
      description = "The deposit chip that is pre-selected when booking.";
    };
    rebookAfterDays = mkOption {
      type = types.int;
      default = 28;
      description = "A finished client with nothing booked gets a 'due to rebook' card after this many days.";
    };
    hours = mkOption {
      type = types.listOf types.str;
      default = [
        "10:00"
        "19:30"
      ];
      description = "First and last bookable time of day; the Book page offers half-hour slots between them.";
    };
    printer = mkOption {
      type = types.str;
      default = "";
      description = "CUPS printer for consent forms and aftercare sheets. Empty: the default printer (the stencil printer prints A4 thermal paper fine).";
    };
    morningBrief = mkOption {
      type = types.nullOr types.str;
      default = "09:30";
      description = "Time of the one daily notification (today's clients, deposits owed, clients due to rebook). null turns it off.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.flattoo-till ];
    environment.etc."flattoo/till.json".text = builtins.toJSON system;

    systemd.user.services.flattoo-till-brief = lib.mkIf (cfg.morningBrief != null) {
      description = "Money: today's clients and deposits owed (notification only)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.flattoo-till}/bin/flattoo-till brief";
        Nice = 15;
      };
    };
    systemd.user.timers.flattoo-till-brief = lib.mkIf (cfg.morningBrief != null) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* ${cfg.morningBrief}";
        Persistent = true;
      };
    };
  };
}
