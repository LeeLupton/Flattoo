#!/usr/bin/env bash
# Offline exercise of flattoo-portfolio and flattoo-profile against a fake home.
set -euo pipefail
export HOME=$TMPDIR/home XDG_CONFIG_HOME=$TMPDIR/home/.config XDG_STATE_HOME=$TMPDIR/home/.local/state
unset DISPLAY
mkdir -p "$HOME/Pictures/phone" "$HOME/Downloads" "$HOME/Documents"
python3 - <<'PY'
import os
from PIL import Image, ImageDraw
home = os.environ["HOME"]
import random
def pic(path, w, h, seed):
    rng = random.Random(seed)
    im = Image.new("RGB", (w, h), (seed * 37 % 255, seed * 91 % 255, seed * 53 % 255))
    d = ImageDraw.Draw(im)
    for k in range(14):  # a distinct scatter of shapes per seed, so the duplicate check sees different pictures
        x, y, r = rng.randrange(w), rng.randrange(h), rng.randrange(80, max(81, min(w, h) // 3))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(rng.randrange(255), rng.randrange(255), rng.randrange(255)))
        d.rectangle([x, y, x + r, y + r // 2], fill=(rng.randrange(255), 255, rng.randrange(255)))
    exif = Image.Exif(); exif[0x0110] = "phone"; exif[0x9003] = "2026:01:01 00:00:00"  # camera model + date
    if path.endswith(".jpg"):
        im.save(path, exif=exif.tobytes())
    else:
        im.save(path)
pic(f"{home}/Pictures/phone/IMG_0001.jpg", 3000, 4000, 1)
pic(f"{home}/Pictures/phone/IMG_0002.jpg", 4000, 3000, 2)
pic(f"{home}/Pictures/phone/IMG_0002 copy.jpg", 4000, 3000, 2)   # duplicate: dropped
pic(f"{home}/Downloads/finished-rose.png", 2400, 2400, 3)
pic(f"{home}/Downloads/Screenshot_2026.png", 1920, 1080, 4)      # screenshot: dropped
pic(f"{home}/Documents/sketch-stencil.png", 2000, 2000, 5)       # stencil: dropped
pic(f"{home}/Pictures/tiny.jpg", 400, 300, 6)                   # too small: dropped
PY
echo "## scan"
flattoo-portfolio scan | tee scan.txt
[ "$(wc -l < scan.txt)" = 3 ] || { echo "expected 3 candidates"; exit 1; }
echo "## status before"
flattoo-portfolio status | grep -q '"new": 3'
echo "## build"
flattoo-profile set studio "Needle & Thread"
out=$(flattoo-portfolio build | tee /dev/stderr | awk '{print $1}')
test -f "$out/index.html" && test -f "$out/contact-sheet.pdf" && test -f "$out/README.txt"
[ "$(ls "$out/web" | wc -l)" = 3 ] && [ "$(ls "$out/square" | wc -l)" = 3 ]
python3 - "$out" <<'PY'
import sys, os
from PIL import Image
out = sys.argv[1]
for f in os.listdir(os.path.join(out, "web")):
    im = Image.open(os.path.join(out, "web", f))
    assert max(im.size) <= 2048, im.size
    assert not im.getexif(), "EXIF must be stripped"
sq = Image.open(os.path.join(out, "square", "001.jpg")); assert sq.size == (1080, 1080), sq.size
print("copies ok: resized, square, no metadata")
PY
echo "## status after"
flattoo-portfolio status | grep -q '"new": 0'
echo "## profile"
flattoo-profile set name "Ava Example"
flattoo-profile add-skill "fine line"
flattoo-profile add-skill "Fine Line"          # duplicate, case-insensitive
flattoo-profile add-skill "cover-ups; rm -rf /" # cleaned
flattoo-profile add-cert "Bloodborne pathogens" 2020-01-01
flattoo-profile show | python3 -c '
import json, sys
p = json.load(sys.stdin)
assert p["skills"] == ["fine line", "cover-ups rm -rf /"], p["skills"]
assert p["name"] == "Ava Example" and p["studio"] == "Needle & Thread"
assert p["certifications"][0]["expires"] == "2020-01-01"
print("profile ok")'
d=$(flattoo-profile render)
test -f "$d/resume.html" && test -f "$d/bio.txt" && test -f "$d/resume.docx" && grep -q "fine line" "$d/resume.html"
echo "## nudges"
flattoo-profile nudges | tee nudges.json
grep -q "expired" nudges.json && grep -q "Not updated" nudges.json
flattoo-profile touch "Instagram"
flattoo-profile exposure | grep -q "Instagram *today"
echo "all ok"
