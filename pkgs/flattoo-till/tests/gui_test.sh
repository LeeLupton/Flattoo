#!/usr/bin/env bash
# The app draws every page under Xvfb and takes its own screenshot; the
# consent save path and the ledger write from the GUI's own functions run too.
set -euo pipefail
export HOME=$TMPDIR/home FLATTOO_TILL_DATA=$TMPDIR/data FLATTOO_TILL_DOCS=$TMPDIR/docs XDG_CONFIG_HOME=$TMPDIR/home/.config
export FLATTOO_TILL_SYSTEM_SETTINGS=$TMPDIR/system-till.json FLATTOO_TILL_NOW="2026-11-14 10:00"
mkdir -p "$HOME/.config/flattoo"
echo '{"pay": {"venmo": "@inkandneedle", "cashapp": "$inkandneedle"}, "review_link": "https://g.page/r/abc/review"}' > "$TMPDIR/system-till.json"
flattoo-till book --client "Maya Chen" --what "Dragon, forearm" --when "today 2pm" --price 400 --deposit 100 >/dev/null
flattoo-till book --client "Jon Park" --what "Script, ribs" --when "tomorrow 11:30" --price 250 --deposit 50 >/dev/null
flattoo-till paid 120 --method cashapp --client "Walk-in" --kind flash >/dev/null
for page in feed pay book papers money settings; do
  xvfb-run -a -s "-screen 0 1280x800x24" flattoo-till gui --page $page --shot "$TMPDIR/$page.png"
  python3 -I - "$TMPDIR/$page.png" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
assert d[:8] == b"\x89PNG\r\n\x1a\n", sys.argv[1]
w, h = struct.unpack(">II", d[16:24])
assert w >= 1000 and h >= 600, (sys.argv[1], w, h)
print(sys.argv[1], w, h)
PY
done
# the QR screen with an amount prefilled (what "get paid 150" from the copilot opens)
xvfb-run -a -s "-screen 0 1280x800x24" flattoo-till pay 150 --client "Maya Chen" --kind deposit --shot "$TMPDIR/qr.png"
test -s "$TMPDIR/qr.png"
# the consent flow: its own window, each step
for step in who statements sign; do
  xvfb-run -a -s "-screen 0 1280x800x24" flattoo-till consent --client "Maya Chen" --what "Dragon, forearm" --step $step --shot "$TMPDIR/consent-$step.png"
  test -s "$TMPDIR/consent-$step.png"
done
echo "ok: gui pages render"
