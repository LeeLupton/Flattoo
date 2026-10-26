# Flattoo

NixOS for a tattoo studio laptop. Hand sketching first, a stencil printer that
prints at true size, a browser, a scanner, phone transfer, and nothing else.
The whole machine is this repository: reinstalling it is one command, every
upgrade is atomic, and the previous system is always one boot-menu entry away.

## What the artist gets

| Need | What is there |
|---|---|
| Draw | Krita (primary), MyPaint, AzPainter, Rnote, Inkscape for lettering, Xournal++ for tracing. GIMP (with G'MIC) installed, not on the panel. ~40 more a sentence away in Ask Flattoo. |
| Never a terminal | **Ask Flattoo** (button next to the menu, `Super+Space`): *"something like Microsoft Paint"*, *"update now"*, *"the printer isn't working"*, *"free up space"*. A fixed set of actions and a curated app catalog behind a plain-English front end; one polkit-guarded root helper; no shell. |
| Learn it without Lee | **Help & How-To**: 23 plain-English pages with screenshots of this very desktop (looks, layouts, scanning, printing, phone photos, updates, the lock, safety). Ask Flattoo *"how do I scan a sketch"* opens the right page. Screenshots are generated in a VM from the real configuration. [docs/wiki.md](docs/wiki.md). |
| Make it theirs | **Looks**: six whole-desktop presets (theme, icons, fonts, wallpaper, panel, workspaces, shortcuts), live. **Layouts**: open-and-place window sets. An i3 tiling session at the login screen. Save your own of each. |
| Then freeze it | **Lock This Setup** bakes the current desktop into the NixOS config: restored at every login, settings kiosk-locked, boot menu hidden, add-ons frozen, GitHub no longer pulled — only weekly nixpkgs security bumps. **Unlock** needs the admin password. |
| Sketch on paper | Simple Scan, then right-click → **Clean Lines** turns the pencil scan into black stencil lines. |
| Print a stencil | Right-click any image/PDF → **Print as Stencil**. Asks for width in inches, prints 1:1 on the `Stencil` queue. |
| Trust the size | **Stencil Printer Calibration** on the panel prints a ruler page: measure the 4.00 in bar. |
| No cable | **Add Bluetooth Stencil Printer** pairs a Phomemo/QuYin or Bluetooth PocketJet and makes it the Stencil queue; the vendor filter's status handshake is relayed over the link. |
| On the shop Wi-Fi | **Add Network Stencil Printer**, or nothing at all: Wi-Fi Phomemo units are found by a subnet sweep, PocketJets by AirPrint, office printers appear on their own. |
| Printer acting up | **Fix Stencil Printer** in the menu re-detects it (USB first, then paired Bluetooth) and clears stuck state. No password. |
| Only a thermal copier | **Print as Stencil** offers the office printer and prints at true size on plain paper. |
| Phone photos | HEIC/WebP/AVIF open everywhere. iPhone by cable (photo roll in the file manager after "Trust"), Android by cable (MTP), or LocalSend over the shop Wi-Fi, no cloud. |
| Tablet | Wacom and most Huion/XP-Pen/Gaomon work on plug-in; display tablets are mapped to their own screen automatically. OpenTabletDriver is one option away for the rest. |
| Screen | 4K laptop panels get 2x scaling on first login; a normal panel is left alone. |
| Office printer | Driverless AirPrint/IPP over Wi-Fi and USB; brlaser, gutenprint, Epson, HP drivers for the rest; Print to PDF. |
| Browser | Firefox with uBlock Origin, telemetry and sponsored tiles off. |
| One thing to remember | The disk passphrase doubles as the screen-unlock password unless the installer is told otherwise. |
| Not thinking about it | Lid = sleep, lock on wake, disk encrypted, nightly upgrades that never touch the running session. |
| Someone else's network | Redirects, rogue router advertisements, source routes and ARP/ND takeovers are ignored and dropped; the laptop never forwards or routes to bogons. A local validating resolver speaks DNS-over-TLS to Quad9, validates DNSSEC itself, answers private reverse zones locally, and steps down only behind a captive portal. Firefox is HTTPS-only. Repo syncs can require signed commits. [docs/network.md](docs/network.md). |

Desktop is XFCE on X11: tablet pressure and cursor behavior are solid there.

## Stencil printers

* **Brother PocketJet 7** — PJ-722, PJ-723 (the Brother S8 stencil kit),
  PJ-762, PJ-763, PJ-773: vendor LPR + CUPS wrapper per model, fetched from
  `download.brother.com` at build time; PJ-723 and PJ-773 chains verified
  end to end (PostScript → Brother raster, options honored).
* **Brother PocketJet 8** — PJ-822/823/862/863/883: driverless over Wi-Fi or
  USB (`ipp-usb`), no driver needed.
* **Phomemo / QuYin** — M08F, M08F Plus/Pro/WS/S, TP81–TP88, T08FS and 70
  more: the vendor's Linux filters and PPDs are built in (pinned archive,
  two mirrors agreed on the hash).

Plug the printer in (or pair it over Bluetooth from the menu); the `Stencil`
queue appears with Letter, no scaling, and the right driver options. The
Phomemo path is exercised end to end on every build against a fake printer
speaking the status protocol decoded from the vendor filter. Details and
what still needs hardware: [docs/printers.md](docs/printers.md).

Stencil paper flips the image twice (carbon onto the top sheet, top sheet
onto skin), so designs print **without** mirroring by default. The
calibration page has an "R" to prove it on your own paper.

## Layout

```
flake.nix                    inputs: nixpkgs 26.05 (release tarball), disko
hosts/shop-laptop/           the studio laptop: flattoo.* settings, disk layout
hosts/installer/             installer ISO + the flattoo-install wizard
modules/                     base, desktop, art, printing, stencil, media, laptop,
                             security, network (edge hardening, Unbound), remote,
                             extras, autoupgrade (+ flattoo-sync), looks, locked, copilot
pkgs/brother-pj/             PocketJet 7 LPR + CUPS wrapper derivations (5 models)
pkgs/phomemo-cups/           Phomemo/QuYin vendor filters + 75 PPDs
pkgs/stencil-tools/          stencil-print, stencil-clean-lines, stencil-calibrate,
                             stencil-queue-setup, stencil-fix-printer, stencil-bt-setup,
                             bluetooth:// CUPS backend, flattoo-session,
                             flattoo-tablet-map (+ tests)
pkgs/flattoo-looks/          flattoo-look, flattoo-layout, i3 config, wallpapers,
                             flattoo-lock / flattoo-unlock (+ tests)
pkgs/flattoo-copilot/        flattoo-copilot, flattoo-admin, catalog.json (+ tests)
pkgs/flattoo-wiki/           Help & How-To: renders wiki/ to HTML + index.json (+ tests)
wiki/pages/, wiki/screenshots/  the artist's help pages and their VM-made screenshots
tests/screenshots.nix        the VM run that takes them (nix build .#screenshots)
scripts/update-screenshots.sh
tests/look-bundle/           sample captured look for checks.locked-eval
files/                       XFCE panel/screensaver/power defaults, Thunar actions
docs/                        install, printers, maintenance, looks, copilot, network, wiki
.github/workflows/           weekly lock bump + eval gate; per-push checks
```

## Install

1. `nix build .#iso` → `result-iso/iso/flattoo-installer-*.iso`. Write it to a
   USB stick (`dd if=... of=/dev/sdX bs=4M status=progress`).
2. Boot the laptop from it (UEFI). `nmtui` for Wi-Fi, then `sudo flattoo-install`.
3. It asks for the target disk, a disk-encryption passphrase (Enter reuses
   it as the artist's screen-unlock password), and a sudo password for
   `lee`, then partitions (GPT, 1 GiB ESP, LUKS2, btrfs), installs, and
   writes the EFI boot entry. 10-25 minutes.
4. Reboot. Passphrase prompt, then the artist's desktop.

Full walkthrough: [docs/install.md](docs/install.md).

## Maintenance

* Change something: edit, `nix flake check`, push to `main`. The laptop
  mirrors `main` into `/etc/nixos` at 03:30 (or after its next boot),
  keeping its own files (hardware, passwords, apps the artist added, a
  locked look), builds, and the change is live at the following power-on.
  Rollback: pick the previous entry in the boot menu.
* The artist: **Ask Flattoo** → *update now* does the same right away;
  *free up space* removes old generations. [docs/copilot.md](docs/copilot.md).
* Security updates: `.github/workflows/update-flake-lock.yml` bumps nixpkgs
  weekly and pushes only if everything still evaluates and the stencil
  tools pass their test.
* In person: `sudo flattoo-sync && sudo nixos-rebuild switch --flake /etc/nixos#shop-laptop`
  (`/etc/nixos` is the laptop's copy: the repo plus this machine's
  `hardware-configuration.nix`, password hashes, `apps.nix`, `look.nix`;
  none of those are in git).
* Remote: `flattoo.remote.tailscale.enable` / `flattoo.remote.ssh.enable`.

More: [docs/maintenance.md](docs/maintenance.md).

## Knobs

All in `hosts/shop-laptop/default.nix`, documented in `modules/default.nix`
and `modules/copilot.nix`: user and admin names, auto-login, lock on
suspend, OpenTabletDriver, stencil density, Brother/Phomemo drivers, default
look, i3 session, AI extras (Upscayl, Real-ESRGAN, rembg — off by default,
nothing in the base image), copilot LLM provider (`none` / `anthropic` /
`ollama`; understanding only, never execution), DNS upstreams and portal
fallback, signed-only repo syncs (`autoUpgrade.allowedSigners`), Tailscale,
SSH, upgrade time, latest kernel. Written on the machine, not in git: `apps.nix` (Ask
Flattoo) and `look.nix` + `look/` (Lock This Setup).
