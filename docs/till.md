# Money: the part of the laptop that gets the artist paid

`modules/till.nix`, `pkgs/flattoo-till`. On by default. The brief was "as
intuitive to make money as it is to scroll on TikTok", and that is the
design: one screen, one thumb, one card at a time, one big button on each,
swipe up for the next. The money loop of a tattoo shop — book, take the
deposit, paperwork, do the work, take the balance, aftercare, review,
rebook — is a feed the artist scrolls, not a set of apps.

## What it is

| Tab | What happens |
|---|---|
| **Feed** | Cards, one per screen: *Next up* (the next client today, what they owe, the one button the money needs), *Later today*, *Deposit owed* (a booking with no deposit yet), *Today* (take, with week/month/year), *Coming up*, *Due to rebook* (done a month ago, nothing booked), *Leave a review* / *Book the next one* (QR cards), *Aftercare*. A *How do you get paid?* card until a payment app is set. |
| **Get paid** | Number pad → kind (deposit/balance/tip/flash/other) → who (from the books or walk-in) → **Show the pay code**: a QR with the amount above it, one tab per configured app, and *Paid ✓ Venmo* / *Paid cash ✓* under it. The tap is what records the payment. |
| **Book** | Client (completes from past clients), what, price (chips), deposit (chips, the usual one preselected), calendar, half-hour slots within shop hours, **Book it**. With a deposit the pay code follows immediately. |
| **Papers** | **Consent form** (three screens: who / the statements / finger signature → PDF) and the **aftercare sheet** (print or show). Recent forms listed with Open / Print. |
| **Money** | Today / week / month / year tiles, every payment, *Export for taxes*, *Open the Business folder*, Settings. |

The feed is built by one pure function, `build_feed()`, from the store;
`flattoo-till feed --json` prints exactly what the GUI shows, which is what
the tests assert on and what the morning brief reads.

## Principles (the same ones as docs/assist.md, applied to money)

1. **Nothing leaves the laptop.** The pay code is a URL into the artist's
   own payment app on the *client's* phone (`venmo.com/<user>?txn=pay&amount=`,
   `cash.app/$<tag>/<amount>`, `paypal.me/<user>/<amount>USD`, a Square
   checkout link, or the Zelle phone/e-mail as text). No API keys, no OAuth,
   no webhook, no sync, no account anywhere. The laptop cannot know whether
   a payment landed; it records what the artist taps.
2. **The artist's tap is the record.** `Paid ✓` writes the ledger line; so
   does `Paid cash ✓`. There is no "pending" state that software resolves.
3. **Plain files the artist owns.** Store: `~/.local/share/flattoo/till/{bookings,ledger,clients}.json`.
   Outputs: `~/Documents/Business/Money/ledger-<year>.csv` (rewritten on every
   payment, so always current), `~/Documents/Business/Consent/<date> <client>.pdf`,
   `~/Documents/Business/Aftercare.pdf`.
4. **Offer, don't act.** The daily brief (`flattoo-till brief`, `systemd.user`
   timer, default 09:30) is one notification: clients today, deposits owed,
   due to rebook. The rebook card suggests; nothing is messaged.
5. **Consent records are never deleted** by the software. 15A NCAC 18A .3206
   (NC tattooing rules) requires a retrievable record per patron — name,
   address, phone, date of birth, signature — kept at least two years and
   shown to the health department on request. The form is that record; the
   footer says so. Under-18 by date of birth stops the flow (G.S. 14-400).
6. **Legal text is a starting point.** The statements on the form are
   plain-language versions of what consent forms in the trade say. Counsel
   review before relying on the release clause is the artist's/maintainer's
   call, not the software's.

## CLI (what the copilot and the tests use)

```
flattoo-till [gui] [--page feed|pay|book|papers|money|settings] [--shot PNG] [--quit-after S]
flattoo-till pay AMOUNT [--client N] [--kind deposit|balance|tip|flash|other]   the QR screen
flattoo-till paid AMOUNT --method venmo|cashapp|paypal|square|zelle|cash|card [--client N] [--kind K] [--booking ID]
flattoo-till book --client N --what W --when "tomorrow 2pm"|"friday 11:30"|"2026-11-20 15:00" [--price P] [--deposit D]
flattoo-till book-gui [--client N] [--what W] [--when T]        the form, prefilled
flattoo-till bookings [today|week|all];  done ID | cancel ID | deposit-paid ID
flattoo-till consent [--client N] [--what W] [--step who|statements|sign]
flattoo-till consent-pdf --client … --dob … --phone … --address … --design … --placement … --signature strokes.json [--photos] OUT.pdf
flattoo-till aftercare show|print|pdf [OUT]
flattoo-till review | booklink                                   the static QR cards
flattoo-till money [today|week|month|year];  export [YEAR]
flattoo-till feed [--json];  brief;  paylink METHOD AMOUNT [NOTE]
flattoo-till settings;  set KEY VALUE;  get KEY
```

`FLATTOO_TILL_NOW="YYYY-MM-DD HH:MM"` pins the clock, `FLATTOO_TILL_DATA`,
`FLATTOO_TILL_DOCS` and `FLATTOO_TILL_SYSTEM_SETTINGS` relocate the store,
the Documents output and `/etc/flattoo/till.json` — the tests use all four.

Times: `parse_when()` takes ISO, `today 3` (afternoon in a tattoo shop),
`tomorrow 11:30`, `friday at 3pm`, a weekday name (next one, never today).

## Copilot

Actions `pay` (amount, client, kind), `book` (client, what, when), `money`
(range), `consent` (client), `aftercare` (show/print), `review` (review/
booking). `money_request()` runs before the catalog so "consent form" and
"schedule an appointment" stop landing on LibreOffice and GNOME Calendar,
and uses whole-word matching so "tip" is not found in "multiple". The LLM
validator whitelists each argument (`clean_name()`, amount regex, ranges).
Tap-sheet rows: **Get paid**, **Book a client**, **Who's next, what's owed**,
**Consent form**.

## Look integration

`flattoo-look` now writes `~/.config/flattoo/palette.json` with every look
(and bundles it); Money reads it for its CSS (background, card, accent,
radius), so it follows the fifteen looks like the notification bubbles and
rofi do. Every look's panel has a **money** launcher next to the copilot.

## Settings

Maintainer, once, in the host config (`/etc/flattoo/till.json`):

```nix
flattoo.till = {
  payments = { venmo = "inkandneedle"; cashapp = "inkandneedle"; paypal = ""; square = ""; zelle = ""; };
  reviewLink = "https://g.page/r/…/review";
  bookingLink = "";            # falls back to the profile's booking link
  currency = "$";
  defaultDeposit = 50;
  rebookAfterDays = 28;
  hours = [ "10:00" "19:30" ];
  printer = "";                # CUPS name; empty = default (the A4 thermal stencil printer works)
  morningBrief = "09:30";      # null = off
};
```

The artist's own entries under Money › Settings (`~/.config/flattoo/till.json`)
win over the system file, key by key.

## Printing papers

Consent copies and aftercare sheets go through `lp` to the default (or
`flattoo.till.printer`) queue. The Phomemo M08F and Brother PJ are A4-width
thermal printers; a one-page PDF prints on them as it would on any printer.

## Tests

- `checks.till-offline` — settings layering (system → user), every pay-link
  shape, plain-English booking times, the feed (next up, deposit owed, money,
  rebook, QR cards, no setup card once an app is set), payments clearing the
  owed card and adding up by day/week/month with the clock pinned across a
  Monday, the CSV, the brief text, the consent PDF (poppler: one page, the
  client, the age, the studio, a statement, the artist, photo permission
  on/off) and the aftercare PDF, shellcheck of the test scripts.
- `checks.till-gui` — every page and the three consent steps render under
  Xvfb and screenshot themselves (`--shot`), the QR screen with an amount
  prefilled included.
- `copilot-matcher` — the phrasings above, the near-misses ("is it charging",
  "multiple screens", "install a booking app", "how do I get more reviews"),
  and the LLM validator on hostile arguments.
- `tests/screenshots.nix` (dialogs half) — six composed Money screenshots for
  the wiki on the Home look.

## Not done, on purpose

No online booking sync, no card reader, no invoices e-mailed, no SMS
reminders: each would need an account and a network path out of the laptop,
which the design rules out. The booking page and review page are shown as
codes; the client's phone does the rest.
