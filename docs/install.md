# Installing on the studio laptop

## Before you start

* An x86_64 (Intel/AMD) laptop booted in UEFI mode. Legacy/CSM off.
* Secure Boot: turn it **off** in firmware for now. The installer and the
  installed system use systemd-boot without signing. Signing (lanzaboote)
  is a follow-up once the machine is in service.
* A 60 GB+ disk. 256 GB is comfortable: Krita + rollbacks + client photos.
* Studio Wi-Fi password. The install downloads ~3 GB from cache.nixos.org.

The installer replaces every partition on the selected laptop disk. Copy any
files you need to keep elsewhere before starting. A system reinstall does not
restore artwork or photos.

## Build the ISO

On an x86_64 Linux machine with Git, [Nix](https://nix.dev/install-nix), internet
access, and space for the ISO and build dependencies:

```sh
git clone --branch main https://github.com/LeeLupton/Flattoo.git
cd Flattoo
nix --extra-experimental-features 'nix-command flakes' build .#iso --out-link result-iso
ls result-iso/iso/
```

The explicit `--out-link result-iso` matches the path used here; the default
output link would be `result`. The ISO embeds this checkout. Make initial
configuration edits before building it, including the
[update source for a fork](../README.md#configuration), then rebuild the ISO.
The installer uses that snapshot and downloads dependencies during installation.

Write it to a USB stick large enough for the ISO. Identify the USB by size,
model, and transport, then unmount any of its mounted partitions:

```sh
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
```

Replace the ISO path below with the actual filename shown by `ls`, and replace
`/dev/sdX` with the **whole USB device**, not one of its partitions. This erases
the USB stick; the laptop's installation disk is selected later in the wizard.

```sh
sudo dd if=/absolute/path/to/flattoo-installer.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Wait for the write to finish before removing the stick.

## Run the installer

1. Boot from the stick. You land on a console as `nixos`.
2. Connect Ethernet, or use `nmtui` → Activate a connection → pick the Wi-Fi network → password.
3. `sudo flattoo-install`

It asks, in order:

| Prompt | What to type |
|---|---|
| Install to which disk | the name from the list, e.g. `nvme0n1`, without `/dev/` |
| Type the disk name again | same name; this erases the disk |
| Passphrase | disk encryption; typed at every power-on; 8+ chars |
| Password for `artist` | Enter at this prompt = same as the disk passphrase; or a different password of at least 4 characters |
| Password for `lee` | sudo; 8+ chars |

Then it partitions (1 GiB ESP, LUKS2, btrfs with `@root @home @nix @log`),
installs, writes the EFI entry, and prints "Done". Remove the USB and run
`reboot`. The wizard's 10–25 minute estimate depends on your connection and
required builds.

## First boot

* Passphrase prompt → auto-login as `artist` → XFCE.
* For administration, log in as `lee`, or run `su - lee` in a terminal and use
  the admin password. The artist account has no sudo access.
* Plug the stencil printer in. Wait ten seconds. Print the calibration page
  from the panel icon. If nothing appears, menu → **Fix Stencil Printer**.
  No cable: menu → **Add Bluetooth Stencil Printer** with the printer in
  pairing mode.
* Phone: iPhone by cable ("Trust this computer" on the phone, then it is in
  the file manager sidebar), Android by cable, or LocalSend over Wi-Fi.
* Tablet: plug it in. Display tablets map to their own screen on their own.
  If a Huion/XP-Pen/Gaomon has no pressure, set
  `flattoo.tablet.openTabletDriver = true` in the repo and push.

## What the installer left behind

`/etc/nixos` on the laptop is the installation source snapshot, without Git
metadata, plus two generated files:

* `hosts/shop-laptop/hardware-configuration.nix` — `nixos-generate-config`
  output for this exact machine. Include required hardware settings in the
  repository used for updates; otherwise remote builds use the generic
  `hardware.nix`. This file is not excluded by `.gitignore`.
* `hosts/shop-laptop/passwords.nix` — sha-512 hashes for the two accounts.
  Never commit. The nightly GitHub pull does not carry it, and
  `users.mutableUsers = true` keeps the on-disk passwords as they are.

Nightly updates read the configured GitHub source, not this local copy, and do
not refresh `/etc/nixos`. See [maintenance](maintenance.md) for separate local
and remote rebuild commands. The artist password and disk passphrase are
separate credentials even when initialized to the same value; changing the
login password does not change the disk passphrase.

## If something goes wrong

* Install fails mid-way: fix, then run `sudo flattoo-install` again; it
  re-partitions from scratch.
* Laptop boots to a black screen after an upgrade: at the boot menu pick the
  previous generation. Then look at `journalctl -b -1 -p err` as `lee`.
* Forgot the LUKS passphrase: the data is gone. Reinstall.
