# Installing on the studio laptop

## Before you start

* The laptop must boot UEFI (every laptop sold since ~2012). Legacy/CSM off.
* Secure Boot: turn it **off** in firmware for now. The installer and the
  installed system use systemd-boot without signing. Signing (lanzaboote)
  is a follow-up once the machine is in service.
* A 60 GB+ disk. 256 GB is comfortable: Krita + rollbacks + client photos.
* Studio Wi-Fi password. The install downloads ~3 GB from cache.nixos.org.

## Build the ISO

On any machine with Nix (flakes enabled):

```sh
git clone https://github.com/LeeLupton/Flattoo
cd Flattoo
nix build .#iso
ls result-iso/iso/
```

Write it to a USB stick (`lsblk` to find it; this erases the stick):

```sh
sudo dd if=result-iso/iso/flattoo-installer-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Run the installer

1. Boot from the stick. You land on a console as `nixos`.
2. Wi-Fi: `nmtui` → Activate a connection → pick the network → password.
3. `sudo flattoo-install`

It asks, in order:

| Prompt | What to type |
|---|---|
| Install to which disk | the name from the list, e.g. `nvme0n1` |
| Type the disk name again | same name; this erases the disk |
| Passphrase | disk encryption; typed at every power-on; 8+ chars |
| Password for `artist` | unlocks the screen after sleep; short is fine |
| Password for `lee` | sudo; 8+ chars |

Then it partitions (1 GiB ESP, LUKS2, btrfs with `@root @home @nix @log`),
installs, writes the EFI entry, and prints "Done". `reboot`.

## First boot

* Passphrase prompt → auto-login as `artist` → XFCE.
* Plug the stencil printer in. Wait ten seconds. Print the calibration page
  from the panel icon.
* Pair the phone with LocalSend (same Wi-Fi) if the artist wants transfers.
* Tablet: Wacom works. Huion/XP-Pen: if pressure is missing, set
  `flattoo.tablet.openTabletDriver = true` in the repo and push.

## What the installer left behind

`/etc/nixos` on the laptop is a copy of this repo plus two files that are
not in git:

* `hosts/shop-laptop/hardware-configuration.nix` — `nixos-generate-config`
  output for this exact machine. Commit it to the repo when convenient
  (it is not secret); the generic `hardware.nix` boots the machine either way.
* `hosts/shop-laptop/passwords.nix` — sha-512 hashes for the two accounts.
  Never commit. The nightly GitHub pull does not carry it, and
  `users.mutableUsers = true` keeps the on-disk passwords as they are.

## If something goes wrong

* Install fails mid-way: fix, then run `sudo flattoo-install` again; it
  re-partitions from scratch.
* Laptop boots to a black screen after an upgrade: at the boot menu pick the
  previous generation. Then look at `journalctl -b -1 -p err` as `lee`.
* Forgot the LUKS passphrase: the data is gone. Reinstall.
