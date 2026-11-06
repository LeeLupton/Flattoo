#!/usr/bin/env bash
# Regenerate the wiki screenshots in a VM and copy them into wiki/screenshots/.
#
#   scripts/update-screenshots.sh            # needs KVM for speed; works without (slow)
#
# The VM run (tests/screenshots.nix) boots the laptop configuration, drives the
# desktop, and writes PNGs plus an index.json of captions. Commit the result;
# the wiki package renders from the committed files, so the laptop never runs
# a VM and CI never needs KVM.
set -euo pipefail
cd "$(dirname "$0")/.."

features="nixos-test big-parallel benchmark uid-range"
if [ ! -e /dev/kvm ]; then
  echo "no /dev/kvm: the VM runs under TCG, expect 30-60 minutes" >&2
fi
# The test derivation asks for the kvm feature; QEMU falls back to TCG by itself.
features="kvm $features"

# Two halves (looks, dialogs+i3): each stays under the time a non-KVM build
# gets; their index.json files are merged.
looks=$(nix build --no-link --print-out-paths --option system-features "$features" .#screenshots-looks)
dialogs=$(nix build --no-link --print-out-paths --option system-features "$features" .#screenshots-dialogs)
mkdir -p wiki/screenshots
rm -f wiki/screenshots/*.png
cp "$looks"/*.png "$dialogs"/*.png wiki/screenshots/
python3 - "$looks/index.json" "$dialogs/index.json" > wiki/screenshots/index.json <<'PY'
import json, sys
print(json.dumps(json.load(open(sys.argv[1])) + json.load(open(sys.argv[2])), indent=2))
PY
chmod 644 wiki/screenshots/*
echo "copied $(ls wiki/screenshots/*.png | wc -l) screenshots from $out"
nix build --no-link .#flattoo-wiki
"$(nix build --no-link --print-out-paths .#flattoo-wiki)"/bin/flattoo-wiki check || true
echo "now: git add wiki/screenshots && git commit"
