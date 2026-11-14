#!/usr/bin/env bash
# Offline: the store, the feed, pay links, the ledger and its CSV, the consent
# and aftercare PDFs, the morning brief — with the clock pinned.
set -euo pipefail
export HOME=$TMPDIR/home FLATTOO_TILL_DATA=$TMPDIR/data FLATTOO_TILL_DOCS=$TMPDIR/docs
export FLATTOO_TILL_SYSTEM_SETTINGS=$TMPDIR/system-till.json XDG_CONFIG_HOME=$TMPDIR/home/.config
export FLATTOO_TILL_NOW="2026-11-14 10:00"
mkdir -p "$HOME/.config/flattoo" "$TMPDIR/data"
cat > "$TMPDIR/system-till.json" <<'J'
{"pay": {"venmo": "@inkandneedle"}, "currency": "$", "default_deposit": 50}
J
echo '{"name": "Sam Rivera", "studio": "Ink & Needle", "city": "Morehead City", "links": {"booking": "https://ink.example/book"}}' > "$HOME/.config/flattoo/profile.json"

# settings: system file, then the artist's own on top
[ "$(flattoo-till get venmo)" = "@inkandneedle" ]
flattoo-till set cashapp '$inkandneedle' >/dev/null
flattoo-till set review_link 'https://g.page/r/abc/review' >/dev/null
[ "$(flattoo-till get cashapp)" = '$inkandneedle' ]
[ "$(flattoo-till get venmo)" = "@inkandneedle" ]
! flattoo-till set nonsense 1 2>/dev/null

# pay links carry the amount where the app allows it
flattoo-till paylink venmo 150 "Deposit Maya" | grep -qx 'https://venmo.com/inkandneedle?txn=pay&amount=150&note=Deposit+Maya'
flattoo-till paylink cashapp 87.50 | grep -qx 'https://cash.app/$inkandneedle/87.5'
flattoo-till set paypal inkneedle >/dev/null
flattoo-till paylink paypal 40 | grep -qx 'https://paypal.me/inkneedle/40USD'
! flattoo-till paylink square 10 2>/dev/null
flattoo-till set zelle 555-010-0000 >/dev/null
flattoo-till paylink zelle 10 | grep -qx '555-010-0000'

# bookings: plain-English times
flattoo-till book --client "Maya Chen" --what "Dragon, forearm" --when "today 2pm" --price 400 --deposit 100 | grep -q "2026-11-14 14:00"
flattoo-till book --client "Jon Park" --what "Script, ribs" --when "tomorrow 11:30" --price 250 --deposit 50 | grep -q "2026-11-15 11:30"
flattoo-till book --client "Ana Ruiz" --what "Flash 12" --when "friday at 3" --price 120 | grep -q "2026-11-20 15:00"
flattoo-till book --client "Old Client" --what "Sleeve session 2" --when "2026-10-01 13:00" --price 500 >/dev/null
flattoo-till bookings today | grep -c . | grep -qx 1
flattoo-till bookings week | grep -c . | grep -qx 3
old=$(flattoo-till bookings all | grep "Old Client" | awk '{print $1}')
flattoo-till done "$old" | grep -q "\[done\]"

# the feed: next up, the deposit owed, today's money, the rebook nudge, the review code
flattoo-till feed --json > feed.json
python3 -I - feed.json <<'PY'
import json, sys
cards = json.load(open(sys.argv[1]))
kinds = [c["kind"] for c in cards]
ids = [c["id"] for c in cards]
assert kinds[0] == "booking" and cards[0]["kicker"] == "Next up" and cards[0]["title"] == "Maya Chen", cards[0]
assert cards[0]["primary"]["do"] == "pay" and cards[0]["primary"]["kind"] == "deposit" and cards[0]["primary"]["amount"] == 100, cards[0]["primary"]
assert any(c["kind"] == "deposit" and c["title"] == "Jon Park" and c["big"] == "$50" for c in cards), kinds
assert not any(c["kind"] == "deposit" and c["title"] == "Ana Ruiz" for c in cards)   # no deposit asked, nothing owed
m = next(c for c in cards if c["kind"] == "money"); assert m["big"] == "$0" and "0 payments" in m["title"], m
r = next(c for c in cards if c["kind"] == "rebook"); assert r["title"] == "Old Client" and r["big"] == "44 days", r
assert "review" in ids and "booklink" in ids and "aftercare" in ids, ids
assert "setup-pay" not in ids
print("feed ok:", kinds)
PY

# payments: the deposit clears the owed card, totals add up, the CSV is rewritten every time
maya=$(flattoo-till bookings today | awk '{print $1}')
flattoo-till paid 100 --method venmo --client "Maya Chen" --kind deposit --booking "$maya" | grep -q '\$100'
flattoo-till bookings today | grep -q "deposit \$100 *\[booked\]"
flattoo-till paid 300 --method cash --client "Maya Chen" --kind balance --booking "$maya" >/dev/null
flattoo-till paid 40 --method cashapp --client "Maya Chen" --kind tip >/dev/null
flattoo-till money today | head -1 | grep -qx '\$440'
flattoo-till money week | grep -qx '\$440'
test -s "$TMPDIR/docs/Money/ledger-2026.csv"
grep -q '^2026-11-14,.*,300.00,Cash,Balance,Maya Chen' "$TMPDIR/docs/Money/ledger-2026.csv"
grep -q '^total,,440.00' "$TMPDIR/docs/Money/ledger-2026.csv"
flattoo-till feed --json > feed2.json
python3 -I - feed2.json <<'PY'
import json, sys
cards = json.load(open(sys.argv[1]))
c0 = cards[0]
assert c0["title"] == "Maya Chen" and c0["primary"]["label"] == "Get paid", c0["primary"]   # paid in full: nothing owed on the button
m = next(c for c in cards if c["kind"] == "money"); assert m["big"] == "$440" and "3 payments" in m["title"], m
print("feed after payments ok")
PY
# the clock moves: yesterday's take is not today's
FLATTOO_TILL_NOW="2026-11-15 09:00" flattoo-till money today | head -1 | grep -qx '\$0'
FLATTOO_TILL_NOW="2026-11-15 09:00" flattoo-till money week | grep -qx '\$440'
FLATTOO_TILL_NOW="2026-11-16 09:00" flattoo-till money week | grep -qx '\$0'   # Monday: new week
FLATTOO_TILL_NOW="2026-11-16 09:00" flattoo-till money month | grep -qx '\$440'

# the morning brief says; it never does
flattoo-till brief | grep -q "1 client today: Maya Chen 2:00 PM"
flattoo-till brief | grep -q "1 deposit owed: Jon Park \$50"
flattoo-till brief | grep -q "Due to rebook: Old Client"
FLATTOO_TILL_NOW="2026-11-17 09:00" flattoo-till brief | grep -q "Nothing booked today"

# consent: a signed PDF with the statements, kept under Documents/Business/Consent
echo '[[[0.1,0.5],[0.2,0.3],[0.3,0.6],[0.4,0.4]],[[0.5,0.5],[0.6,0.5]]]' > sig.json
flattoo-till consent-pdf --client "Maya Chen" --dob 1996-04-02 --phone 555-0100 --address "1 Main St" --design "Dragon" --placement "left forearm" --signature sig.json --photos consent.pdf >/dev/null
head -c 5 consent.pdf | grep -q '%PDF-'
pdfinfo consent.pdf | grep -q "^Pages: *1$"
pdftotext consent.pdf - | grep -q "Maya Chen"
pdftotext consent.pdf - | grep -q "age 30"
pdftotext consent.pdf - | grep -q "left forearm"
pdftotext consent.pdf - | grep -q "Ink & Needle"
pdftotext consent.pdf - | grep -q "18 or older"
pdftotext consent.pdf - | grep -q "Sam Rivera"
pdftotext consent.pdf - | { ! grep -q "not granted"; }    # photos were allowed
pdftoppm -png -r 30 consent.pdf consent-page && test -s consent-page-1.png
# a minor is refused by the GUI step; the headless renderer still prints the age it was given
flattoo-till consent-pdf --client "Kid" --dob 2012-01-01 --signature sig.json kid.pdf >/dev/null
pdftotext kid.pdf - | grep -q "age 14"
pdftotext kid.pdf - | grep -q "not granted"
flattoo-till aftercare pdf aftercare.pdf | grep -q aftercare.pdf
pdfinfo aftercare.pdf | grep -q "^Pages: *1$"
pdftotext aftercare.pdf - | grep -q "Ink & Needle"
pdftotext aftercare.pdf - | grep -q "No soaking"
pdftotext aftercare.pdf - | grep -q "When to call"
echo "ok: store, feed, pay links, ledger, csv, brief, pdfs"
