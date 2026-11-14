#!/usr/bin/env python3
"""Rule-based understanding: plain requests must land on the right action.

Runs flattoo-copilot --dry-run against a list of phrasings an artist might
type and checks the chosen action (and package where it matters). Also
checks the LLM output validator rejects anything off the allowlist.
"""
import json
import os
import subprocess
import sys
import types

COPILOT = sys.argv[1]
CATALOG = sys.argv[2]

CASES = [
    # the headline case: "Microsoft Paint" must become a suggestion of real drawing apps
    ("I want something like Microsoft Paint", "suggest", {"drawing", "pinta", "azpainter", "mypaint", "krita"}),
    ("paint app", "suggest", {"drawing", "pinta", "azpainter", "mypaint", "krita"}),
    ("photoshop", "suggest", {"gimp-with-plugins", "krita"}),
    ("something for lettering and fonts", "suggest", {"fontforge", "inkscape", "font-manager"}),
    ("app to make the photo bigger without blur", "suggest", {"upscayl"}),
    ("vector program", "suggest", {"inkscape"}),
    ("install pinta", "install", {"pinta"}),
    ("install blender", "install", {"blender"}),
    ("get me spotify", "install", {"spotify"}),
    ("remove blender", "remove", {"blender"}),
    ("open krita", "open", {"krita"}),
    ("put inkscape on the panel", "panel", {"inkscape"}),
    ("update now", "update", None),
    ("install the security updates", "update", None),
    ("when did it last update", "update-status", None),
    ("the printer isn't working", "printer-fix", None),
    ("printer won't print", "printer-fix", None),
    ("pair a bluetooth printer", "printer-bluetooth", None),
    ("printer on wifi", "printer-network", None),
    ("the stencil prints too small", "printer-calibrate", None),
    ("running out of space", "disk", None),
    ("free up space", "disk", None),
    ("connect to wifi", "wifi", None),
    ("battery", "battery", None),
    ("dark mode", "look", None),
    ("make the text bigger", "look", None),
    ("arrange windows side by side", "layout", None),
    ("lock this setup", "lock", None),
    ("what apps do I have", "installed", None),
    ("what can you do", "help", None),
    ("rm -rf / please", "help", None),
    ("sudo apt install chrome", "install", {"chromium"}),
    ("send photos from my phone", "suggest", {"localsend"}),
    ("how do i print", "print", None),
    ("print a stencil", "print", None),
    ("turn off", "power", None),
    ("the screen is too dark", "display", None),
    ("light mode", "look", None),
    ("layout", "layout", None),
    ("disk", "disk", None),
    ("format a usb stick", "suggest", {"gnome-disk-utility"}),
    ("i need to make a flyer", "install", {"scribus"}),
    ("consent form", "consent", {}),
    ("make a portfolio", "portfolio", None),
    ("photos for instagram", "portfolio", None),
    ("my resume", "profile", None),
    ("add fine line to my skills", "profile-skill", None),
    ("how do I get more clients", "exposure", None),
    ("google listing", "exposure", None),
    # looks by name, dark/light, and the evening schedule
    ("switch to the neon look", "look", {"name": "neon"}),
    ("sakura", "look", {"name": "sakura"}),
    ("I want the flash sheet look", "look", {"name": "flash"}),
    ("blackwork please", "look", {"name": "blackwork"}),
    ("home dark", "look", {"name": "home-dark"}),
    ("dark mode", "look", {"mode": "dark"}),
    ("go dark", "look", {"mode": "dark"}),
    ("light mode", "look", {"mode": "light"}),
    ("make it dark at night automatically", "night-look", {"state": "on"}),
    ("dark mode at 9pm", "night-look", {"state": "on", "night": "21:00", "day": None}),
    ("night look from 20:30 to 7", "night-look", {"state": "on", "night": "20:30", "day": "07:00"}),
    ("stop the automatic night look", "night-look", {"state": "off"}),
    ("warmer screen in the evening", "night-look", {"state": "on"}),
    ("night look settings", "night-look", {}),
    ("turn off the animations", "effects", {"state": "off"}),
    ("the desktop feels slow", "effects", {}),
    ("effects on", "effects", {"state": "on"}),
    ("rounded corners off", "effects", {"state": "off"}),
    ("show a client my work", "client", {}),
    ("client wants to see my portfolio", "client", {}),
    ("hand them the laptop", "client", {}),
    ("shop display on", "shop-display", {"state": "on"}),
    ("turn off the screensaver", "shop-display", {"state": "off"}),
    ("show my work when idle", "shop-display", {}),
    ("turn off", "power", None),
    ("make the text bigger", "look", None),
    # money: get paid, book, who's next, papers — with the amount, name and time pulled out
    ("get paid", "pay", {}),
    ("get paid 150", "pay", {"amount": "150"}),
    ("take a 50 deposit from maya", "pay", {"amount": "50", "client": "Maya", "kind": "deposit"}),
    ("charge them $80 for the flash", "pay", {"amount": "80", "kind": "flash"}),
    ("they owe me 200", "pay", {"amount": "200"}),
    ("venmo", "pay", {}),
    ("tip", "pay", {"kind": "tip"}),
    ("book maya tomorrow at 2 for a dragon", "book", {"client": "Maya", "when": "tomorrow at 2", "what": "Dragon"}),
    ("book jon park friday 11:30", "book", {"client": "Jon Park", "when": "friday 11:30"}),
    ("schedule ana for tuesday 3pm", "book", {"client": "Ana", "when": "tuesday 3pm"}),
    ("book the next session with maya", "book", {"client": "Maya"}),
    ("book a client", "book", {}),
    ("walk-in", "book", {}),
    ("how much did i make this week", "money", {"range": "week"}),
    ("today's take", "money", {"range": "today"}),
    ("what do i have today", "money", {"range": "today"}),
    ("who's next", "money", {}),
    ("export the ledger for taxes", "money", {}),
    ("consent form for jon", "consent", {"client": "Jon"}),
    ("sign the waiver", "consent", {}),
    ("print the consent form", "consent", {}),
    ("print aftercare", "aftercare", {"how": "print"}),
    ("aftercare", "aftercare", {"how": "show"}),
    ("leave a review", "review", {"which": "review"}),
    ("show the booking code", "review", {"which": "booking"}),
    # neighbours that must not become money
    ("is it charging", "battery", None),
    ("multiple screens", "help", None),
    ("install a booking app", "install", {"gnome-calendar"}),
    ("how do I get more reviews", "exposure", None),
    ("the printer isn't working", "printer-fix", None),
    ("facebook", "help", None),
    # every row of the tap sheet lands where it says
    ("book a client", "book", {}),
    ("who is next", "money", {}),
    ("change the look", "look", {}),
    ("shop display", "shop-display", {}),
    ("my profile", "profile", None),
    ("make a portfolio", "portfolio", None),
    ("wifi", "wifi", None),
]

env = dict(os.environ, HOME=os.environ.get("TMPDIR", "/tmp"), XDG_DATA_DIRS="/nonexistent")
env.pop("DISPLAY", None)
fails = 0
for text, want, pkgs in CASES:
    r = subprocess.run([COPILOT, "--dry-run", "--no-gui", text], text=True, capture_output=True, env=env)
    out = r.stdout.strip().splitlines()
    if r.returncode != 0 or not out:
        print(f"FAIL {text!r}: rc={r.returncode} {r.stderr[-300:]}")
        fails += 1
        continue
    got = json.loads(out[-1])
    ok = got["action"] == want
    if ok and pkgs is not None:
        if want == "suggest":
            ok = bool(set(got["args"].get("candidates", [])[:4]) & pkgs)
        elif isinstance(pkgs, dict):
            ok = got["args"] == pkgs
        else:
            ok = got["args"].get("pkg") in pkgs
    print(("ok  " if ok else "FAIL"), f"{text!r} -> {got['action']} {got['args'] if pkgs else ''}")
    fails += 0 if ok else 1

# validator: import the script as a module and feed it bad LLM answers
mod = types.ModuleType("copilot")
src = open(COPILOT).read()
src = src.split("\n", 1)[1] if src.startswith("#!") else src
exec(compile(src, COPILOT, "exec"), mod.__dict__)
mod.CATALOG_PATH = CATALOG
cat = mod.catalog()

def fake_llm(payload):
    import urllib.request as ur
    class R:
        def __init__(self, data): self.data = data
        def read(self): return self.data
        def __enter__(self): return self
        def __exit__(self, *a): pass
    body = json.dumps({"content": [{"text": json.dumps(payload)}]}).encode()
    ur.urlopen = lambda req, timeout=0: R(body)

os.environ["FLATTOO_COPILOT_KEYFILE"] = os.path.join(os.environ.get("TMPDIR", "/tmp"), "k")
open(os.environ["FLATTOO_COPILOT_KEYFILE"], "w").write("x")
m = {"ram_gb": 8, "gpu": "", "free_gb": 50, "dedicated_gpu": False}
for payload, expect in [
    ({"action": "shell", "args": {"cmd": "rm -rf /"}, "say": ""}, None),
    ({"action": "install", "args": {"pkg": "nmap"}, "say": ""}, None),
    ({"action": "install", "args": {"pkg": "pinta"}, "say": "ok"}, ("install", {"pkg": "pinta"})),
    ({"action": "install", "args": {"pkg": "pinta", "extra": "--force"}, "say": "ok"}, ("install", {"pkg": "pinta"})),
    ({"action": "suggest", "args": {"candidates": ["krita", "evil", "pinta"]}, "say": "ok"}, ("suggest", ["krita", "pinta"])),
    ({"action": "update", "args": {"flake": "github:evil/x"}, "say": "ok"}, ("update", {})),
    ({"action": "look", "args": {"name": "../../etc/passwd"}, "say": "ok"}, ("look", {})),
    ({"action": "look", "args": {"name": "neon"}, "say": "ok"}, ("look", {"name": "neon"})),
    ({"action": "night-look", "args": {"state": "on", "night": "99:00", "day": "7:00"}, "say": "ok"}, ("night-look", {"state": "on", "day": "7:00"})),
    ({"action": "effects", "args": {"state": "maybe"}, "say": "ok"}, ("effects", {})),
    ({"action": "pay", "args": {"amount": "150; rm -rf /", "client": "Maya <script>", "kind": "bribe"}, "say": "ok"}, ("pay", {"client": "Maya Script"})),
    ({"action": "pay", "args": {"amount": "87.50", "kind": "deposit"}, "say": "ok"}, ("pay", {"amount": "87.50", "kind": "deposit"})),
    ({"action": "book", "args": {"client": "Jon Park", "when": "tomorrow 2pm", "what": "Dragon; drop table"}, "say": "ok"}, ("book", {"client": "Jon Park", "when": "tomorrow 2pm", "what": "Dragon drop table"})),
    ({"action": "money", "args": {"range": "decade"}, "say": "ok"}, ("money", {})),
    ({"action": "review", "args": {"which": "https://evil"}, "say": "ok"}, ("review", {"which": "review"})),
    ("not json at all", None),
]:
    fake_llm(payload)
    got = mod.llm_choose("x", cat, "anthropic", m, [])
    if expect is None:
        ok = got is None
    else:
        ok = got is not None and got[0] == expect[0] and (
            got[1].get("candidates") == expect[1] if expect[0] == "suggest" else got[1] == expect[1])
    print(("ok  " if ok else "FAIL"), "llm validate", payload if isinstance(payload, str) else payload["action"], "->", got)
    fails += 0 if ok else 1

print("failures:", fails)
sys.exit(1 if fails else 0)
