# Flattoo

NixOS for a tattoo studio laptop. Hand sketching first, a stencil printer that
prints at true size, a browser, a scanner, phone transfer, and nothing else.
The whole machine is this repository: reinstalling it is one command, every
upgrade is atomic, and the previous system is always one boot-menu entry away.

## What the artist gets

| Need | What is there |
|---|---|
| Draw | Krita (primary), MyPaint, Inkscape for lettering, Xournal++ for tracing. GIMP installed, not on the panel. |
| Sketch on paper | Simple Scan, then right-click → **Clean Lines** turns the pencil scan into black stencil lines. |
| Print a stencil | Right-click any image/PDF → **Print as Stencil**. Asks for width in inches, prints 1:1 on the `Stencil` queue. |
| Trust the size | **Stencil Printer Calibration** on the panel prints a ruler page: measure the 4.00 in bar. |
| Printer acting up | **Fix Stencil Printer** in the menu re-detects it and clears stuck state. No password. |
| Only a thermal copier | **Print as Stencil** offers the office printer and prints at true size on plain paper. |
| Phone photos | HEIC/WebP/AVIF open everywhere. iPhone by cable (photo roll in the file manager after "Trust"), Android by cable (MTP), or LocalSend over the shop Wi-Fi, no cloud. |
| Tablet | Wacom and most Huion/XP-Pen/Gaomon work on plug-in; display tablets are mapped to their own screen automatically. OpenTabletDriver is one option away for the rest. |
| Screen | 4K laptop panels get 2x scaling on first login; a normal panel is left alone. |
| Office printer | Driverless AirPrint/IPP over Wi-Fi and USB; brlaser, gutenprint, Epson, HP drivers for the rest; Print to PDF. |
| Browser | Firefox with uBlock Origin, telemetry and sponsored tiles off. |
| One thing to remember | The disk passphrase doubles as the screen-unlock password unless the installer is told otherwise. |
| Not thinking about it | Lid = sleep, lock on wake, disk encrypted, nightly upgrades that never touch the running session. |

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

Plug the printer in; the `Stencil` queue appears by itself with Letter,
no scaling, and the right driver options. Details and what was verified
without hardware: [docs/printers.md](docs/printers.md).

Stencil paper flips the image twice (carbon onto the top sheet, top sheet
onto skin), so designs print **without** mirroring by default. The
calibration page has an "R" to prove it on your own paper.

## Layout

```
flake.nix                    inputs: nixpkgs 26.05 (release tarball), disko
hosts/shop-laptop/           the studio laptop: flattoo.* settings, disk layout
hosts/installer/             installer ISO + the flattoo-install wizard
modules/                     base, desktop, art, printing, stencil, media,
                             laptop, security, remote, extras, autoupgrade
pkgs/brother-pj/             PocketJet 7 LPR + CUPS wrapper derivations (5 models)
pkgs/phomemo-cups/           Phomemo/QuYin vendor filters + 75 PPDs
pkgs/stencil-tools/          stencil-print, stencil-clean-lines, stencil-calibrate,
                             stencil-queue-setup, stencil-fix-printer,
                             flattoo-session, flattoo-tablet-map (+ tests)
files/                       XFCE panel/screensaver/power defaults, Thunar actions
docs/                        install, printers, maintenance
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
  pulls at 03:30 (or after its next boot) and the change is live at the
  following power-on. Rollback: pick the previous entry in the boot menu.
* Security updates: `.github/workflows/update-flake-lock.yml` bumps nixpkgs
  weekly and pushes only if everything still evaluates and the stencil
  tools pass their test.
* In person: `sudo nixos-rebuild switch --flake /etc/nixos#shop-laptop`
  (`/etc/nixos` is the copy the installer left, with this machine's
  `hardware-configuration.nix` and the password hashes; neither is in git).
* Remote: `flattoo.remote.tailscale.enable` / `flattoo.remote.ssh.enable`.

More: [docs/maintenance.md](docs/maintenance.md).

## Knobs

All in `hosts/shop-laptop/default.nix`, documented in `modules/default.nix`:
user and admin names, auto-login, lock on suspend, OpenTabletDriver,
stencil density, Brother/Phomemo drivers, AI extras (Upscayl, Real-ESRGAN,
rembg — off by default, nothing in the base image), Tailscale, SSH, upgrade
time, latest kernel.
