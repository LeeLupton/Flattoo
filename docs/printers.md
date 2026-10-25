# Stencil printers

Design rule: the artist plugs something in and it works, or the menu's
**Fix Stencil Printer** makes it work, and nobody edits a config file.

## How the queue works

`modules/stencil.nix` installs a udev rule: when any USB printer-class
device (or a Phomemo/QuYin unit that enumerates as vendor-specific) appears,
`stencil-queue-setup.service` runs; it also runs 45 s after every boot and
from the **Fix Stencil Printer** menu entry (polkit lets the artist start
exactly that unit). It:

1. waits for `cupsd`,
2. finds a stencil printer in `lpinfo -v` / `lpinfo -m` (rules below),
3. creates the `Stencil` queue (or re-points it if the URI changed),
4. sets stencil defaults: `media-default=Letter` (A4 if the PPD has no
   Letter), `print-scaling-default=none`, monochrome, not shared,
   `printer-error-policy=retry-current-job` (a paper-out never leaves the
   queue stopped), and per-driver options.

`stencil-print` then sends a Letter/A4 PDF whose page size matches the queue,
with `print-scaling=none`, so the CUPS PDF filter never rescales.

| Printer | Detection | Driver | Options set |
|---|---|---|---|
| Brother PJ-722/723/762/763/773 | `usb://Brother/PJ-7xx` | vendor LPR + CUPS wrapper for that model | `BrHalftonePattern=BrBinary`, `BrDensity=<flattoo.stencil.density>`, `BrMirror=OFF` |
| Brother PJ-822/823/862/863/883 | `driverless:` entry containing `PJ-8` (ipp-usb or Wi-Fi) | none (IPP Everywhere) | — |
| Phomemo / QuYin (M08F family, TP81–TP88, T08FS, M08 Pro, …) | `usb://<vendor>/<model>`; the PPD whose name is the longest prefix of the model string: `M08F-WS-Q803` → `M08F-WS`, `M08F_PLUS` → `M08F`, `TP88` → `TP88` | vendor filters + 75 PPDs | `ColorOption=GrayScale`, `Rotate=0` |
| Anything else | not touched | — | — |

No stencil printer at all? **Print as Stencil** offers the other printers on
the laptop and prints at true size on plain paper, for shops that transfer
with a thermal copier.

## Bluetooth

Phomemo/QuYin printers and the Bluetooth PocketJets (PJ-762/763/773) talk
Bluetooth Classic serial (SPP, RFCOMM). Two pieces make that a normal CUPS
queue:

* `bluetooth://MAC/channel` **backend** (`pkgs/stencil-tools/backend/bluetooth`,
  Python on the kernel's native RFCOMM sockets). It streams the job to the
  printer and relays everything the printer says back to the filter on the
  CUPS back channel, and answers the side channel. The scheme name matters:
  Phomemo's filter looks for `bluetooth:` in `DEVICE_URI` and switches to
  its Bluetooth mode. Discovery (`lpinfo -v`) lists paired printers.
* **Add Bluetooth Stencil Printer** (menu; `stencil-bt-setup`): scans 12 s,
  lists what it found, pairs (tries 0000 / 1234 / `default` / 1111 before
  asking for a PIN), trusts, reads the serial-port channel with `sdptool`
  (default 1), and calls `stencil-queue-setup --uri bluetooth://MAC/ch
  --model <name>`. **Fix Stencil Printer** and the boot check also fall
  back to a paired Bluetooth printer when nothing is on USB; a USB cable
  takes precedence while it is plugged in.

### The Phomemo status protocol (decoded from `rastertoM08F`)

The vendor filter interrogates the printer before and during a job. Without
answers it polls forever, which is why plain `rfcomm`+`serial://` would not
work. Queries are three bytes, replies start with `1a`:

| Filter sends | Meaning | Printer answers |
|---|---|---|
| `1f 11 09` | name / serial | `1a 08` + 15 bytes |
| `1f 11 07` | firmware version | `1a 07 vv vv vv` |
| `1f 11 11` | paper? | `1a 06 89` present, `1a 06 88` out |
| `1f 11 12` | busy? | `1a 05 98` idle, `1a 05 99` busy |
| `1f 11 43` | ready | `1a 0f 0c` |
| `1f 11 35 00` | sent before data in Bluetooth mode | — |
| — | temperature | `1a 03 a8` ok, `1a 03 a9` overheated |
| — | job canceled | `1a 0b b8` |
| — | transfer error | `1a 70` |

In Bluetooth mode the filter asks only for the name and skips the
paper/busy gating. In USB mode it asks name, paper, busy, paper, then
prints. Page data is ESC/POS raster (`1d 76 30`, 196 bytes = 1568 px wide
at 203 dpi for Letter).

The explicit `checks.x86_64-linux.phomemo-chain` check runs the whole path
against a simulated printer: PDF →
`pdftoraster` (vendor PPD) → `rastertoM08F` → `bluetooth` backend → a fake
printer that answers with the packets above. It asserts both processes exit
0 and the printer received a 1568 px wide raster page.

Run it from the repository root with
`nix build .#checks.x86_64-linux.phomemo-chain --print-build-logs`, or as part
of a full `nix flake check`. A normal package build and the current CI workflows
do not run this check.

What still needs the real printer: that its SPP channel accepts the stream
(the phone apps use the same transport and command set) and the PIN, which
varies by model. Brother PJ over Bluetooth is wired the same way but
unverified beyond the raster chain; Brother's own Linux support statement
is "via USB".

## Brother PocketJet 7 (PJ-722/723/762/763/773; the S8 kit is a PJ-723)

Vendor driver 1.2.0-1 (Brother, September 2026), two packages per model,
fetched from `download.brother.com` with pinned hashes
(`pkgs/brother-pj/models.nix`). All five were fetched, unpacked and diffed:
identical modulo the model name.

* `lpr.nix` — `rastertobrpt1`, `filterpj7xx`, `psconvertpt1`, option tools
* `cupswrapper.nix` — PPD + `brcupsconfpt1`; the CUPS filter is generated at
  build time the same way Brother's installer generates it

Both are 32-bit binaries patched to the i686 glibc loader. Brother's option
tool has `/opt/brother/PTouch/<model>/inf/...` compiled in, so
`modules/printing.nix` symlinks each of the five at boot (systemd-tmpfiles).
The PJ-723 and PJ-773 chains were run end to end in the build environment:
PostScript calibration page in, 984 KB of PJ raster out, and
`BrHalftonePattern` / `BrDensity` / `BrMirror` / `PageSize` all present in
the rc file the raster converter read.

PPD options (`lpoptions -p Stencil -l`):

| Option | Values | Stencil use |
|---|---|---|
| `BrHalftonePattern` | BrBinary, BrDither, BrErrorDiffusion | Binary for line work; dither when `--shading` |
| `BrDensity` | 0–10 | Carbon transfer strength; 6 default, raise for thin lines |
| `BrMirror` | OFF/ON | Always OFF; mirroring is done in software when asked |
| `PageSize` | Letter, A4, Legal, Roll*, Perf*, Retract*, ContinuousLetter | Cut-sheet stencil paper = Letter |
| `BrSpeed` | 0sp…3sp, PRD | Slower = darker on some papers |

## Brother PocketJet 8 (PJ-822/823/862/863/883)

AirPrint printers with no Linux LPR package. Over Wi-Fi they appear
driverless via Avahi; over USB, `ipp-usb` exposes them as IPP and
`stencil-queue-setup` picks the `driverless:` entry. Density/halftone are
then IPP attributes (`print-quality`, `print-darkness` where the firmware
exposes it).

## Phomemo / QuYin (M08F, M08F Plus, M08F Pro, M08F-WS, M08FS, TP81–TP88, T08FS, …)

`pkgs/phomemo-cups` ships the vendor's Linux driver: three prebuilt x86_64
CUPS filters (`rastertoM08F`, `rastertoD480`, `rastertolabelmxxx`; the M08F
one bundles OpenCV) and 75 PPDs. Phomemo's own download page is
JavaScript-only with no stable URL, so the build pulls the EasyOS repack
(`phomemo-printer-driver-20260506.pet`, a gzip tarball with an md5 footer)
from two mirrors that returned byte-identical files; the hash is pinned.
`autoPatchelfHook` resolved every library (libcups, libcupsimage, zlib,
libstdc++); nothing is missing at runtime.

What was verified without hardware: the M08F filter reads the CUPS raster
`pdftoraster` makes from the vendor PPD (203 dpi, RGB 8-bit, Letter and A4),
converts the page ("gray end … 1568 x 2041"), and reports "Printed data has
been sent". What needs the printer: before sending page data the filter
polls printer status (`1f 11 09`) over the USB back channel and waits for
the reply; with no printer attached it polls forever. That is normal for
this driver and is why the queue is only created when the printer is
physically present.

Options worth knowing: `Darkness` (Default/Fine/Medium/Thick/Dedicated),
`DegreeOfBlackRecognition` 1–10 (threshold), `Resolution` 203 dpi,
`PageSize` A4/Letter.

To use a newer archive from phomemo.com (zip, tar or .pet), set
`flattoo.stencil.phomemo.driverArchive = ../../vendor/<file>;` — the install
phase is layout-agnostic (any x86_64 `rasterto*` plus any PPDs).

Bluetooth: see above. BLE-only units (M02X class) are not covered; they need
GATT, not serial.

## Office printers and scanners

Driverless IPP (AirPrint / Mopria / IPP Everywhere) over Wi-Fi and USB covers
nearly everything sold since 2015. For the rest: `brlaser` (Brother lasers),
`gutenprint`, `epson-escpr`, `hplip` (HP, including its scanner backend).
Scanners: SANE, `sane-airscan` for Wi-Fi all-in-ones, `hplip`.

## Verify a new printer

Print the calibration page (panel icon, or `stencil-calibrate`). The 4.00 in
bar must measure 101.6 mm. Transfer the R to paper the way you would a
stencil; it must read correctly. If the bar is off, something re-enabled
scaling: **Fix Stencil Printer** resets the queue.
