# Flattoo

NixOS for a tattoo studio laptop. Hand sketching first, a stencil printer that
prints at true size, a browser, a scanner, phone transfer, and nothing else.
This repository defines the system and builds a USB installer for an
**x86_64 (Intel/AMD) laptop**. The desktop is XFCE on X11. Updates build a
new system generation for the next boot; earlier generations remain available
in the boot menu within the configured retention limits.

**Start here:** [Install](#install) · [First stencil](#print-your-first-stencil) ·
[Configure](#configuration) · [Maintain](#maintenance) ·
[Troubleshoot](#troubleshooting)

## What the artist gets

| Need | What is there |
|---|---|
| Draw | Krita (primary), MyPaint, Inkscape for lettering, Xournal++ for tracing. GIMP installed, not on the panel. |
| Sketch on paper | Simple Scan, then right-click → **Clean Lines** turns the pencil scan into black stencil lines. |
| Print a stencil | Right-click any image/PDF → **Print as Stencil**. Asks for width in inches, prints 1:1 on the `Stencil` queue. |
| Trust the size | **Stencil Printer Calibration** on the panel prints a ruler page: measure the 4.00 in bar. |
| No cable | **Add Bluetooth Stencil Printer** pairs a Phomemo/QuYin or Bluetooth PocketJet and makes it the Stencil queue; the vendor filter's status handshake is relayed over the link. |
| Printer acting up | **Fix Stencil Printer** in the menu re-detects it (USB first, then paired Bluetooth) and clears stuck state. No password. |
| Only a thermal copier | **Print as Stencil** offers the office printer and prints at true size on plain paper. |
| Phone photos | HEIC/WebP/AVIF open everywhere. iPhone by cable (photo roll in the file manager after "Trust"), Android by cable (MTP), or LocalSend over the shop Wi-Fi, no cloud. |
| Tablet | Kernel tablet support plus automatic display-tablet mapping. OpenTabletDriver is an option for models that need it. |
| Screen | 4K laptop panels get 2x scaling on first login; a normal panel is left alone. |
| Office printer | Driverless AirPrint/IPP over Wi-Fi and USB; brlaser, gutenprint, Epson, HP drivers for the rest; Print to PDF. |
| Browser | Firefox with uBlock Origin, telemetry and sponsored tiles off. |
| One thing to remember | The installer can use the disk passphrase as the initial screen-unlock password. |
| Not thinking about it | Lid = sleep, lock on wake, disk encrypted, nightly upgrades that never touch the running session. |

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
queue is configured with Letter (A4 when the driver has no Letter option),
no scaling, and the matching driver options. An explicit Phomemo integration
check exercises the filter and Bluetooth backend against a simulated printer;
it does not run on every package build. Physical printer behavior, including
Bluetooth pairing and transport, still needs validation on the target model.
See [printer setup and validation details](docs/printers.md).

Stencil paper flips the image twice (carbon onto the top sheet, top sheet
onto skin), so designs print **without** mirroring by default. The
calibration page has an "R" to prove it on your own paper.

## Install

### 1. Prepare the build machine and laptop

You need:

- An **x86_64 Linux build machine** with Git and [Nix](https://nix.dev/install-nix),
  internet access, and space for the ISO and Nix build dependencies. The flake
  currently exposes only `x86_64-linux` packages.
- A USB stick large enough for the resulting ISO.
- An x86_64 laptop booted in **UEFI mode**, with **Secure Boot disabled**,
  a target disk of **at least 60 GB**, and an internet connection during install.

**Installation erases the entire selected laptop disk.** Copy any artwork,
photos, and other files you need to keep elsewhere first. The USB-writing step
also overwrites the selected USB device.

### 2. Clone and build the installer

Run on the build machine:

```sh
git clone --branch main https://github.com/LeeLupton/Flattoo.git
cd Flattoo
nix --extra-experimental-features 'nix-command flakes' build .#iso --out-link result-iso
ls result-iso/iso/
```

The ISO is under `result-iso/iso/`, named `flattoo-installer-…-x86_64.iso`.
`--out-link result-iso` explicitly sets that directory link; plain `nix build`
uses `result` by default.

The ISO contains a snapshot of this checkout. Make initial configuration edits
**before building it**; the installer does not fetch a newer Flattoo checkout
at install time. If using a fork, also change the automatic-update source as
described in [Configuration](#configuration).

### 3. Write the ISO to USB

Use a USB image writer, or run the following on Linux. First identify the USB
by its size, model, and transport:

```sh
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
```

Unmount any mounted partitions on that USB. Replace **both** placeholders below:
`/absolute/path/to/flattoo-installer.iso` is the actual file shown by `ls`, and
`/dev/sdX` is the **whole USB device**, not a partition such as `/dev/sdX1`.

```sh
sudo dd if=/absolute/path/to/flattoo-installer.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Wait for the command to finish before removing the stick. The USB device here
is separate from the laptop disk you will select in the installer.

### 4. Boot the USB and install

Boot the laptop from the USB in UEFI mode. At the installer console, connect
Ethernet or use `nmtui` to join Wi-Fi, then start the wizard:

```sh
nmtui
sudo flattoo-install
```

The wizard asks for:

| Prompt | What to enter |
|---|---|
| Target disk | A disk name from the displayed list, such as `nvme0n1` or `sda`, **without `/dev/`**. |
| Erase confirmation | The same disk name. All existing partitions on that disk will be replaced. |
| Disk-encryption passphrase | At least 8 characters, entered twice. You type this at each power-on. |
| Password for `artist` | Press **Enter at this prompt** to reuse the disk passphrase for screen unlock, or enter a separate password of at least 4 characters. |
| Password for `lee` | At least 8 characters, entered twice. This is the administrator's login and sudo password. |

These are the default account names. The installer creates GPT partitions,
a 1 GiB EFI partition, and a LUKS2-encrypted btrfs system. It downloads
dependencies and prints **Done** when installation finishes. Its estimate of
about 3 GB and 10–25 minutes depends on the connection and required builds.

Remove the USB and run `reboot`. Enter the disk passphrase; the default setup
logs in automatically as `artist` and opens XFCE.

Full walkthrough: [docs/install.md](docs/install.md).

## Print your first stencil

1. Connect the stencil printer by USB, or put it in pairing mode and open
   **Add Bluetooth Stencil Printer** from the application menu.
2. Open **Stencil Printer Calibration** from the panel. Measure the **4.00 in
   (101.6 mm)** bar and check the **R** through your normal transfer process.
3. In the file manager, right-click an image or PDF and select **Print as Stencil**.
   Enter the desired width **in inches**. Mirroring is off by default.
4. For a pencil scan, use Simple Scan, then right-click the saved image and
   choose **Clean Lines** before printing.

If the printer queue does not appear, use **Fix Stencil Printer** from the menu.
It checks USB first, then paired Bluetooth printers. If you use a thermal copier,
**Print as Stencil** can send a true-size page to an available office printer.

The same tools are available in a terminal on the installed laptop:

```sh
stencil-print --width 3.5 design.png
stencil-print --width 3.5 --dry-run stencil-preview.pdf design.png
lpstat -v
```

Replace `design.png` with your file. The first command prints; `--dry-run`
writes a PDF preview without sending a job.

## Configuration

Edit [`hosts/shop-laptop/default.nix`](hosts/shop-laptop/default.nix).
All `flattoo.*` options are defined in [`modules/default.nix`](modules/default.nix).
Common settings include:

| Option | Default | Purpose |
|---|---|---|
| `flattoo.user.name` / `flattoo.admin.name` | `"artist"` / `"lee"` | Artist account and administrator account. |
| `flattoo.desktop.autoLogin` | `true` | Open the artist's desktop after disk unlock. |
| `flattoo.desktop.lockOnSuspend` | `true` | Require the artist's password after sleep. |
| `flattoo.tablet.openTabletDriver` | `false` | Enable OpenTabletDriver for tablets that need it; replaces the kernel Wacom driver. |
| `flattoo.stencil.density` | `6` | Brother print density, from `0` to `10`. |
| `flattoo.extras.enable` | `false` | Optional upscaling and background-removal tools. |
| `flattoo.remote.tailscale.enable` / `flattoo.remote.ssh.enable` | `false` / `false` | Optional remote maintenance; SSH also requires an admin public key. |
| `flattoo.autoUpgrade.flake` | `"github:LeeLupton/Flattoo#shop-laptop"` | Source for automatic system updates; `null` disables them. |
| `flattoo.autoUpgrade.time` | `"03:30"` | Scheduled update time in the laptop's configured time zone. |

For a fork, change the existing `autoUpgrade.flake` value to
`"github:YOUR_USER/YOUR_REPO#shop-laptop"`, or set it to `null` for manual updates.
Otherwise nightly updates continue to use `LeeLupton/Flattoo`, not your local
customizations. New source files in a Git checkout must be added with `git add`
before Nix includes them in the flake. Keep `passwords.nix` out of Git.

## Maintenance

### Validate a repository change

From the repository root on an x86_64 Linux machine with Nix's `nix-command`
and `flakes` features enabled:

```sh
# Evaluate the flake and both host derivations without building the system.
nix flake check --no-build
nix eval --raw .#nixosConfigurations.shop-laptop.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.installer.config.system.build.isoImage.drvPath

# Build and run the stencil round-trip test.
nix build .#checks.x86_64-linux.stencil-tools --print-build-logs

# Run the simulated Phomemo filter/backend integration check.
nix build .#checks.x86_64-linux.phomemo-chain --print-build-logs
```

For all declared checks, run `nix flake check --print-build-logs`. This also
builds the laptop system closure and printer packages, so it can take much
longer. It does not build the installer ISO; use the ISO command above for that.
Use `nix fmt -- hosts/shop-laptop/default.nix` to format an edited Nix file;
pass other changed `.nix` paths as needed. Commit and push validated changes
to the repository and branch configured for the laptop's updates.

### Automatic updates

The default laptop timer runs at **03:30 America/New_York**, with up to
**45 minutes of randomized delay**. A missed run is caught up after the next
boot. A successful build becomes the default for the **following boot**;
the job does not switch the running desktop or reboot the laptop.

The weekly [lock-update workflow](.github/workflows/update-flake-lock.yml)
updates dependencies on Mondays at 09:17 UTC. It evaluates both hosts, runs
the stencil round-trip test, and builds the PJ-723 wrapper before pushing a
changed lock file. The dedicated Phomemo integration check is available above;
the current CI workflows do not run it.

### Apply a change immediately

Log in as `lee` for administration, or run `su - lee` in a terminal and enter
the administrator password. The `artist` account does not have sudo.

Choose the source you intend to apply:

| Source | Command |
|---|---|
| Latest configured repository (shown here with the default) | `sudo nixos-rebuild switch --flake github:LeeLupton/Flattoo#shop-laptop --refresh` |
| Local installation copy, including your local edits | `sudo nixos-rebuild switch --flake /etc/nixos#shop-laptop` |

`/etc/nixos` is the source snapshot left by the installer, with generated
`hosts/shop-laptop/hardware-configuration.nix` and `passwords.nix`. It is not a
Git checkout and does not automatically track `main`. Nightly repository
updates do not incorporate edits made only in this copy. Keep the password
file local; include required hardware changes in your update source.

More: [docs/maintenance.md](docs/maintenance.md).

## Troubleshooting

| Symptom | Next step |
|---|---|
| `nix: command not found` | Install Nix on the build machine; see the prerequisite link above. |
| Nix says an experimental feature is disabled | Use `nix --extra-experimental-features 'nix-command flakes' …`, as in the ISO build example, or enable both features in your Nix configuration. |
| Installer says there is no internet | Connect Ethernet or run `nmtui`, then retry. The installer checks access to `https://cache.nixos.org/nix-cache-info`. |
| Installer reports legacy BIOS mode | Reboot using the firmware's UEFI USB entry. |
| No `Stencil` queue or a stopped printer | Use **Fix Stencil Printer**; inspect `lpstat -v` and the [printer guide](docs/printers.md). |
| Printed size is wrong | Print the calibration page, check the 4.00 in bar, and reset the queue with **Fix Stencil Printer** before trying again. |
| An upgrade fails or has not appeared | As `lee`, inspect `systemctl status nixos-upgrade.timer` and `sudo journalctl -u nixos-upgrade.service -n 100 --no-pager`. A successful staged build takes effect only after reboot. |
| A new generation fails to boot | Select a known-good earlier generation in the boot menu, then fix or revert the update source before the next automatic run. |

Re-running `flattoo-install` repartitions the target disk from scratch. Use
system rebuilds and boot-menu generations for maintenance of an existing install.
System rollback does not restore artwork or photos; keep separate copies of
those files. The boot menu retains up to 14 generations, and weekly garbage
collection removes generations older than 21 days.

## Layout

| Path | Contents |
|---|---|
| [`flake.nix`](flake.nix) / [`flake.lock`](flake.lock) | Nixpkgs 26.05 and disko inputs, pinned dependencies, hosts, packages, and checks. |
| [`hosts/shop-laptop/`](hosts/shop-laptop/) | Laptop settings, hardware imports, and disk layout. |
| [`hosts/installer/`](hosts/installer/) | Installer ISO and `flattoo-install` wizard. |
| [`modules/`](modules/) | Desktop, art, printing, media, laptop, security, remote access, and updates. |
| [`pkgs/brother-pj/`](pkgs/brother-pj/) / [`pkgs/phomemo-cups/`](pkgs/phomemo-cups/) | Vendor printer packaging. |
| [`pkgs/stencil-tools/`](pkgs/stencil-tools/) | Stencil tools, Bluetooth backend, session helpers, and tests. |
| [`files/`](files/) | XFCE defaults and file-manager actions. |
| [`docs/`](docs/) | Installation, printer, and maintenance guides. |
| [`.github/workflows/`](.github/workflows/) | Push/PR checks and the weekly dependency update. |
