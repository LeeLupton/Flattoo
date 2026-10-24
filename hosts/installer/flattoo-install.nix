# `flattoo-install`: the one command on the installer ISO.
{ pkgs }:
pkgs.writeShellApplication {
  name = "flattoo-install";
  runtimeInputs = with pkgs; [
    coreutils
    util-linux
    gnugrep
    gawk
    gnused
    curl
    mkpasswd
    pciutils
    disko
    nixos-install-tools
    cryptsetup
  ];
  text = ''
    SRC="''${FLATTOO_SRC:-/etc/flattoo}"
    HOST="''${FLATTOO_HOST:-shop-laptop}"
    WORK=/tmp/flattoo-src
    KEYFILE=/tmp/flattoo-luks.key

    bold() { printf '\033[1m%s\033[0m\n' "$*"; }
    die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
    ask_secret() { # ask_secret "prompt" minlen  -> prints the secret on stdout
      local v1 v2
      while true; do
        read -rsp "$1: " v1; echo >&2
        read -rsp "$1 (again): " v2; echo >&2
        if [ "$v1" != "$v2" ]; then echo "  They differ. Try again." >&2; continue; fi
        if [ "''${#v1}" -lt "$2" ]; then echo "  At least $2 characters." >&2; continue; fi
        printf '%s' "$v1"; break
      done
    }

    [ "$(id -u)" = 0 ] || die "run as root:  sudo flattoo-install"
    [ -d /sys/firmware/efi ] || die "this machine booted in legacy BIOS mode; switch it to UEFI in firmware setup"
    [ -d "$SRC" ] || die "flake source not found at $SRC"

    bold "Flattoo installer"
    echo

    # 1. Network: the build pulls from cache.nixos.org.
    if ! curl -sfI --max-time 8 https://cache.nixos.org/nix-cache-info >/dev/null; then
      die "no internet. Run 'nmtui' to join Wi-Fi, then run flattoo-install again."
    fi
    echo "network: ok"

    # 2. Target disk.
    echo
    bold "Disks"
    lsblk -d -o NAME,SIZE,MODEL,TRAN -e 7,11
    echo
    LIVE_DEV="$(findmnt -n -o SOURCE /iso 2>/dev/null | sed 's/[0-9]*$//; s/p$//' || true)"
    read -rp "Install to which disk (name only, e.g. nvme0n1 or sda)? " DISKNAME
    DISK="/dev/$DISKNAME"
    [ -b "$DISK" ] || die "$DISK is not a block device"
    case "$LIVE_DEV" in *"$DISKNAME"*) die "$DISK is the installer medium" ;; esac
    SIZE_GB=$(( $(blockdev --getsize64 "$DISK") / 1000000000 ))
    [ "$SIZE_GB" -ge 60 ] || die "$DISK is ''${SIZE_GB} GB; 60 GB is the floor for Krita + rollbacks"
    echo
    printf '\033[31mEVERYTHING on %s (%s GB) will be erased.\033[0m\n' "$DISK" "$SIZE_GB"
    read -rp "Type the disk name again to confirm: " CONFIRM
    [ "$CONFIRM" = "$DISKNAME" ] || die "aborted"

    # 3. Secrets.
    echo
    bold "Disk encryption passphrase (typed at every power-on)"
    LUKS_PASS="$(ask_secret "Passphrase" 8)"
    echo
    bold "Account passwords"
    ARTIST_PASS="$(ask_secret "Password for 'artist' (unlocks the screen after sleep)" 4)"
    ADMIN_PASS="$(ask_secret "Password for 'lee' (sudo)" 8)"

    # 4. Writable copy of the flake + machine-specific bits.
    rm -rf "$WORK"
    cp -r --no-preserve=mode,ownership "$SRC" "$WORK"
    chmod -R u+w "$WORK"
    HOSTDIR="$WORK/hosts/$HOST"
    [ -d "$HOSTDIR" ] || die "host $HOST not in flake"

    nixos-generate-config --no-filesystems --show-hardware-config > "$HOSTDIR/hardware-configuration.nix"
    echo "hardware-configuration.nix: written"
    if lspci | grep -qi nvidia; then
      echo
      echo "NOTE: Nvidia GPU detected. Mesa/nouveau will drive it. For the proprietary"
      echo "      driver add hardware.nvidia settings to hosts/$HOST/hardware-configuration.nix later."
    fi

    ARTIST_HASH="$(mkpasswd -m sha-512 "$ARTIST_PASS")"
    ADMIN_HASH="$(mkpasswd -m sha-512 "$ADMIN_PASS")"
    cat > "$HOSTDIR/passwords.nix" <<EOF
    # Written by flattoo-install. Not in git.
    { config, ... }:
    {
      users.users.\''${config.flattoo.user.name}.hashedPassword = "$ARTIST_HASH";
      users.users.\''${config.flattoo.admin.name}.hashedPassword = "$ADMIN_HASH";
    }
    EOF
    chmod 600 "$HOSTDIR/passwords.nix"

    # 5. LUKS passphrase for the format step only.
    umask 077
    printf '%s' "$LUKS_PASS" > "$KEYFILE"
    trap 'shred -u "$KEYFILE" 2>/dev/null || true' EXIT

    # 6. Partition, encrypt, format, install. One step.
    echo
    bold "Installing. This downloads about 3 GB; 10-25 minutes on studio Wi-Fi."
    disko-install \
      --flake "$WORK#$HOST" \
      --disk main "$DISK" \
      --write-efi-boot-entries \
      --extra-files "$WORK" /etc/nixos

    echo
    bold "Done."
    echo "  * The laptop boots to the passphrase prompt, then straight into the artist's desktop."
    echo "  * The flake copy with this machine's hardware file is at /etc/nixos on the new system."
    echo "    Commit hosts/$HOST/hardware-configuration.nix to the repo when convenient;"
    echo "    everything boots without it."
    echo "  * Nightly upgrades pull github:LeeLupton/Flattoo. Push to main; it lands at the next power-on."
    echo
    echo "Remove the USB stick and run:  reboot"
  '';
}
