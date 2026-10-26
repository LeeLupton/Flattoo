# Nightly upgrades.
#
# How "secure automatic" works here:
#   1. GitHub Actions (.github/workflows/update-flake-lock.yml) bumps the
#      nixpkgs lock weekly, evaluates the laptop config, and only pushes to
#      main when evaluation succeeds.
#   2. At 03:30 (or after the next boot if the laptop was off) flattoo-sync
#      refreshes the laptop's copy of the repo at /etc/nixos from GitHub,
#      keeping the files that belong to this machine only: the detected
#      hardware, the password hashes, the apps the artist added through Ask
#      Flattoo (apps.nix) and a locked look (look.nix, look/). Then the
#      system is built from /etc/nixos and made the *boot default*. The
#      running session is untouched; the change lands at the next power-on.
#   3. If the new generation misbehaves, the previous one is one entry down
#      in the boot menu. Nothing is ever half-applied.
#
# flattoo.autoUpgrade.flake is where upgrades come from. A github: reference
# is mirrored as above; a local path (what the lock sets) is built as is.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo.autoUpgrade;
  flakeHost = config.flattoo.flakeHost;
  isGithub = cfg.flake != null && lib.hasPrefix "github:" cfg.flake;
  # github:owner/repo[/ref]#attr  ->  url + ref
  ghParts = lib.splitString "/" (
    lib.removePrefix "github:" (lib.head (lib.splitString "#" cfg.flake))
  );
  ghUrl = "https://github.com/${lib.elemAt ghParts 0}/${lib.elemAt ghParts 1}.git";
  ghRef = if lib.length ghParts > 2 then lib.elemAt ghParts 2 else "main";

  sync = pkgs.writeShellApplication {
    name = "flattoo-sync";
    runtimeInputs = with pkgs; [
      git
      openssh # ssh-keygen, for commit signature checks
      rsync
      coreutils
    ];
    text = ''
      # Refresh /etc/nixos from the upstream repo, keeping this machine's own files.
      REPO=''${FLATTOO_REPO:-/etc/nixos}
      ETC=''${FLATTOO_ETC:-/etc/flattoo}
      MIRROR=''${FLATTOO_MIRROR:-/var/lib/flattoo/upstream}
      if [ -e "$ETC/locked" ]; then
        echo "flattoo-sync: locked; building the local copy only"; exit 0
      fi
      if [ ! -r "$ETC/upstream" ]; then
        echo "flattoo-sync: no upstream configured"; exit 0
      fi
      read -r url ref < "$ETC/upstream"
      mkdir -p "$(dirname "$MIRROR")"
      if [ -d "$MIRROR/.git" ]; then
        git -C "$MIRROR" remote set-url origin "$url"
        git -C "$MIRROR" fetch -q --depth 1 origin "$ref"
      else
        rm -rf "$MIRROR"
        git clone -q --depth 1 --branch "$ref" --no-checkout "$url" "$MIRROR"
        git -C "$MIRROR" fetch -q --depth 1 origin "$ref"
      fi
      tip=$(git -C "$MIRROR" rev-parse --short FETCH_HEAD)
      # A hijacked route to GitHub (or GitHub itself) cannot push config onto
      # this machine when the tip must carry a signature from an allowed key.
      if [ -s "$ETC/allowed_signers" ]; then
        if ! git -C "$MIRROR" -c gpg.format=ssh -c gpg.ssh.program=${pkgs.openssh}/bin/ssh-keygen \
              -c gpg.ssh.allowedSignersFile="$ETC/allowed_signers" \
              verify-commit FETCH_HEAD >/dev/null 2>&1; then
          echo "flattoo-sync: REFUSED $tip from $url ($ref): commit is not signed by a key in $ETC/allowed_signers; keeping the local copy"
          exit 1
        fi
        echo "flattoo-sync: $tip signature ok"
      fi
      git -C "$MIRROR" reset -q --hard FETCH_HEAD
      rsync -a --delete \
        --exclude=/.git \
        --exclude='/hosts/*/hardware-configuration.nix' \
        --exclude='/hosts/*/passwords.nix' \
        --exclude='/hosts/*/apps.nix' \
        --exclude='/hosts/*/look.nix' \
        --exclude=/look \
        "$MIRROR/" "$REPO/"
      if [ -d "$REPO/.git" ]; then
        # A locked-then-unlocked machine keeps a local history; a flake built
        # from a git directory only sees tracked files, so track the sync.
        git -C "$REPO" add -A
        git -C "$REPO" -c user.name=flattoo-sync -c user.email=flattoo-sync@localhost \
          commit -q -m "sync from $url ($ref) $(git -C "$MIRROR" rev-parse --short HEAD)" || true
      fi
      echo "flattoo-sync: /etc/nixos now at $(git -C "$MIRROR" rev-parse --short HEAD) from $url ($ref)"
    '';
  };
in
{
  config = lib.mkIf (cfg.flake != null) {
    environment.systemPackages = [ sync ];
    environment.etc."flattoo/upstream" = lib.mkIf isGithub {
      text = "${ghUrl} ${ghRef}\n";
    };
    environment.etc."flattoo/allowed_signers" = lib.mkIf (cfg.allowedSigners != [ ]) {
      text = lib.concatMapStrings (k: k + "\n") cfg.allowedSigners;
    };

    system.autoUpgrade = {
      enable = true;
      # Always built from the local copy; flattoo-sync refreshes it first.
      flake = if isGithub then "/etc/nixos#${flakeHost}" else cfg.flake;
      operation = "boot";
      dates = cfg.time;
      randomizedDelaySec = "45min";
      persistent = true;
      allowReboot = false;
      flags = [ ];
    };

    systemd.services.nixos-upgrade = {
      path = [ sync ];
      # No network, no sync: the local copy still builds (a no-op when
      # nothing changed).
      serviceConfig.ExecStartPre = "-${sync}/bin/flattoo-sync";
      # Builds are background work. Keep the UI responsive if the laptop was
      # off at 03:30 and the timer fires during the day.
      serviceConfig.Nice = 15;
      serviceConfig.IOSchedulingClass = "idle";
      serviceConfig.CPUWeight = 20;
    };
  };
}
