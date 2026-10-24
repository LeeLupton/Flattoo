# Stencil printers

## How the queue works

`modules/stencil.nix` installs a udev rule: when a Brother PJ or a
Phomemo/QuYin M08F-class device appears on USB, `stencil-queue-setup.service`
runs (also 45 s after every boot). It:

1. waits for `cupsd`,
2. finds the printer in `lpinfo -v`,
3. creates the `Stencil` queue (or re-points it if the URI changed),
4. sets stencil defaults: `media-default=Letter` (A4 if the PPD has no
   Letter), `print-scaling-default=none`, monochrome, not shared, and on
   Brother `BrHalftonePattern=BrBinary`, `BrDensity=<flattoo.stencil.density>`,
   `BrMirror=OFF`.

`stencil-print` then sends a Letter/A4 PDF whose page size matches the queue,
with `print-scaling=none`, so the CUPS PDF filter never rescales. Run
`stencil-queue-setup` by hand (as root) if a queue was edited into a bad state.

## Brother PocketJet PJ-723 (Brother S8 kit)

Vendor driver, version 1.2.0-1 (Brother, September 2026):

* `pkgs/brother-pj/lpr.nix` — `pj723lpr-1.2.0-1.i386.rpm`
  (`rastertobrpt1`, `filterpj723`, `psconvertpt1`, option tools)
* `pkgs/brother-pj/cupswrapper.nix` — `pj723cupswrapper-1.2.0-1.i386.rpm`
  (PPD + `brcupsconfpt1`; the CUPS filter is generated at build time the
  same way Brother's installer generates it)

Both are 32-bit binaries patched to the i686 glibc loader. Brother's option
tool has `/opt/brother/PTouch/pj723/inf/...` compiled in, so
`modules/printing.nix` places a symlink there (systemd-tmpfiles). The chain
was run end to end in the build environment: a PostScript calibration page
produced 984 KB of PJ raster, and `BrHalftonePattern`/`BrDensity`/`BrMirror`/
`PageSize` all showed up in the rc file the raster converter read.

PPD options worth knowing (`lpoptions -p Stencil -l`):

| Option | Values | Stencil use |
|---|---|---|
| `BrHalftonePattern` | BrBinary, BrDither, BrErrorDiffusion | Binary for line work; dither when `--shading` |
| `BrDensity` | 0–10 | Carbon transfer strength; 6 default, raise for thin lines |
| `BrMirror` | OFF/ON | Always OFF; mirroring is done in software when asked |
| `PageSize` | Letter, A4, Legal, Roll*, Perf*, Retract*, ContinuousLetter | Cut-sheet stencil paper = Letter |
| `BrSpeed` | 0sp…3sp, PRD | Slower = darker on some papers |

Other PocketJet 7 models (PJ-722/762/763/773) use the same driver family;
swap the model string and the two `dlfp` download IDs in `pkgs/brother-pj/`.

## Brother PJ-8xx (PJ-822/823/862/863/883)

AirPrint printers. Over Wi-Fi they appear driverless via Avahi; over USB,
`ipp-usb` exposes them as IPP and `stencil-queue-setup` picks the
`driverless:` entry. No vendor driver needed. Density/halftone are then IPP
attributes (`print-quality`, `print-darkness` if the firmware exposes it).

## Phomemo M08F / M08F Plus / M08F Pro (and TP88, Ozer, ORGSTA rebrands)

Phomemo's Linux driver contains prebuilt x86_64 CUPS filters
(`rastertoM08F`, `rastertoD480`, `rastertolabel…`) and PPDs, but the
download page is JavaScript-only with no stable URL, so the build cannot
fetch it. Once:

1. Download the Linux driver from <https://phomemo.com/pages/drivers>
   (Driver → Linux). The EasyOS repack at
   `distro.ibiblio.org/easyos/amd64/packages/pet/pet_packages-excalibur/phomemo-printer-driver-20260506.pet`
   is the same filters; `.pet` is accepted too.
2. Save it as `vendor/phomemo-linux-driver.<zip|tar.gz|tar.xz|pet>`.
   `vendor/` is git-ignored because the files are not redistributable;
   for the laptop's nightly pull to build it, commit it to a **private**
   fork or put the archive on the laptop and point the option at an
   absolute path there.
3. In `hosts/shop-laptop/default.nix`:
   ```nix
   flattoo.stencil.phomemo.enable = true;
   flattoo.stencil.phomemo.driverArchive = ../../vendor/phomemo-linux-driver.zip;
   ```
4. `nix build .#nixosConfigurations.shop-laptop.config.system.build.toplevel`
   prints the filters and PPDs it found.

Only USB is wired up; Phomemo's Linux filters do not speak Bluetooth.

## Verify a new printer

Print the calibration page (panel icon, or `stencil-calibrate`). The 4.00 in
bar must measure 101.6 mm. Transfer the R to paper the way you would a
stencil; it must read correctly. If the bar is off, something re-enabled
scaling: `sudo stencil-queue-setup` resets the queue.
