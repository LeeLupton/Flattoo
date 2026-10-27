# Without the keyboard

Some people will not type. The desktop is laid out for them — single-tap
icons, the dock, the app grid, the power sheet, swipes — and
`modules/touch.nix` plus a few pieces elsewhere cover what still asked for
keys. What is left is the boot passphrase (replaceable by a FIDO2 key) and
typing inside apps.

## Ask Flattoo as a sheet

`flattoo-copilot` with no request opens a rofi sheet (`share/flattoo/rofi/copilot.rasi`,
colours from the look) of the common requests: each row is a plain request
fed through the same rule-based understanding as typed text (`SHEET` in the
script), so nothing new is interpreted. "Add an app" lists every catalog app
that is not installed (name, category, blurb, hardware notes) and installs
the tapped one after the usual confirmation. "Type something else…" opens the
text box (`--typed` skips the sheet). The sheet is skipped when rofi is not
on the PATH or when a request is given on the command line.

## Voice (opt-in)

`flattoo.copilot.voice.enable = true` adds whisper.cpp and a 150 MB `base.en`
model to the closure (a fixed-output fetch, hash-pinned) and a "Say it" row
to the sheet. `flattoo-listen` records `flattoo.copilot.voice.seconds` (6)
seconds with `pw-record` (or `arecord`), runs `whisper-cli -nt -np` on the
laptop, prints the text; the copilot shows "I heard: … Do that?" before
acting. About two seconds per request on a laptop CPU; nothing leaves the
machine. Off by default so the model is not downloaded for everyone.

## On-screen keyboard

`flattoo.desktop.onScreenKeyboard` (default on): `onboard`, started at
login, hidden, with auto-show through AT-SPI (`services.gnome.at-spi2-core`),
the Phone layout, docked at the bottom, `hide-on-key-press` so a real
keyboard puts it away. Settings are a dconf profile
(`programs.dconf.profiles.user`). `flattoo-keyboard` toggles it over D-Bus
(`org.onboard.Onboard.Keyboard.ToggleVisible`) and is the **Keyboard** item
on every look's panel (`keyboard` launcher). The lock screen embeds it
(`xfce4-screensaver` `/lock/embedded-keyboard/{enabled,command}` in the seed
XML: `onboard --xid`); the slick greeter gets `onscreen-keyboard=true`.

## Fingerprint

`flattoo.desktop.fingerprint = true`: `services.fprintd`. NixOS wires fprint
into PAM for login, the lock screen and sudo (password remains). Enrol as the
maintainer: `sudo fprintd-enroll artist`.

## FIDO2 key for the disk

`flattoo.disk.fido2 = true`: `crypttabExtraOpts = ["fido2-device=auto"
"token-timeout=10s"]` on `cryptroot`, the systemd-cryptsetup FIDO2 token
plugin and the `fido_id` udev helper copied into stage 1 (systemd initrd
copies only what is listed), `usbhid`/`hid_generic` modules. Enrol once with
the key plugged in:

    sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/disk-main-luks

At boot the splash waits ten seconds for a key (plug in, touch) and falls
back to the passphrase prompt. `fido2-token -L` (libfido2) lists keys.
`systemd-cryptenroll --wipe-slot=fido2` removes the enrolment. The
passphrase slot is never touched.

## Show a Client

`flattoo-showcase client` is a GTK viewer of its own (pygobject): full
screen, black, one piece at a time, a tap or swipe moves on (the left fifth
goes back), auto-advance every 8 s, a round **Done** button in the corner and
a counter at the bottom. Keys other than Esc/arrows are swallowed; the window
is the only thing reachable. On exit the screen locks.

## What still needs keys

The passphrase on the boot splash without a FIDO2 key; text inside apps
(file names, résumé fields, Krita's dialogs) — the on-screen keyboard
covers those; `flattoo-lock`/`sudo` for the maintainer.
