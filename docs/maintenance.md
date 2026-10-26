# Maintenance

## The update pipeline

```
nixpkgs 26.05 (security fixes)        you (edits, pushes)
          │                                   │
          ▼                                   ▼
GitHub Actions, Mondays:  nix flake update → evaluate both hosts →
build stencil-tools + run its test → build the Brother driver → push main
          │
          ▼
laptop, 03:30 nightly (or after the next boot):
flattoo-sync   mirror main into /etc/nixos, keeping hardware-configuration.nix,
               passwords.nix, apps.nix (Ask Flattoo), look.nix + look/ (the lock)
nixos-rebuild boot --flake /etc/nixos#shop-laptop
          │
          ▼
next power-on runs the new generation; the old ones stay in the boot menu
```

With `flattoo.autoUpgrade.allowedSigners` set, `flattoo-sync` verifies the
fetched tip's SSH signature and refuses anything else ([network.md](network.md)).

Locked setup (`/etc/flattoo/locked`): `flattoo-sync` does nothing — the
repo is frozen on the laptop — and `flattoo-nixpkgs-update` bumps only
`nixpkgs` in `/etc/nixos/flake.lock` on Mondays, so security fixes still
arrive. See [looks.md](looks.md).

Properties:

* Nothing is ever half-applied. A failed build leaves the running system
  untouched; the nightly timer tries again tomorrow.
* The build runs at `Nice=15` / idle IO, so if the laptop was off at 03:30
  and the timer fires mid-session, the artist does not notice.
* Fourteen generations are kept in the boot menu; `nix-collect-garbage`
  runs weekly and removes anything older than 21 days.
* Only `cache.nixos.org` is trusted as a binary cache, with its key pinned.

## Day to day

| Task | Command |
|---|---|
| Try a change locally before pushing | `nix flake check && nix build .#nixosConfigurations.shop-laptop.config.system.build.toplevel` |
| Apply right now, in person | `sudo flattoo-sync && sudo nixos-rebuild switch --flake /etc/nixos#shop-laptop` |
| Apply now, as the artist | Ask Flattoo → *update now* |
| What the artist installed | `cat /etc/nixos/hosts/shop-laptop/apps.nix`, `/var/log/flattoo-admin.log` |
| DNS: which mode, is it validating | `cat /run/flattoo/dns-mode`, `unbound-host -D -v nixos.org`, `journalctl -t flattoo-dns` |
| Edge firewall table | `sudo nft list table inet flattoo-edge` |
| See what the nightly job did | `journalctl -u nixos-upgrade -b -1` or `systemctl status nixos-upgrade.timer` |
| Roll back permanently | `sudo nixos-rebuild switch --rollback` |
| Which printer queues exist | `lpstat -v` |
| Recreate the Stencil queue | `sudo stencil-queue-setup` |
| Print a stencil from the shell | `stencil-print --width 3.5 design.png` |
| Reformat the Nix files | `nix fmt` |

## Website and releases

* **Website** (`.github/workflows/pages.yml`): every push that touches the
  wiki, docs or README rebuilds `nix build .#site` and publishes it to GitHub
  Pages — landing page with the download button, Help & How-To, rendered
  docs. One-time: repo Settings → Pages → Source: *GitHub Actions*.
* **Releases** (`.github/workflows/release.yml`): `git tag v2026.10.1 && git
  push origin v2026.10.1` builds the installer ISO and attaches it with
  `SHA256SUMS` to a GitHub Release; the site's Download button points at the
  latest. Running the workflow by hand makes a pre-release named by the
  build number. Assets must stay under 2 GiB.

## Adding software

For everyone, permanently: add the package to the relevant module
(`modules/art.nix` for drawing, `modules/media.nix` for utilities). Search
names at <https://search.nixos.org/packages?channel=26.05>. Push.

For the artist to install themselves: add it to the copilot catalog,
`pkgs/flattoo-copilot/share/flattoo/catalog.json`, with the words they
would use for it. See [copilot.md](copilot.md).

## Changing the artist's defaults

* Look (theme, panel, wallpaper, workspaces, shortcuts): `flattoo.look.default`
  picks the preset applied at first login; presets live in
  `pkgs/flattoo-looks/share/looks/`. `files/xfce/panel-default.xml` is the
  panel before any look is applied.
* Right-click actions: `files/thunar/uca.xml`.
* Screen lock / lid: `flattoo.desktop.lockOnSuspend`, `modules/laptop.nix`.

## Remote access

Off by default. To turn on:

```nix
flattoo.remote.tailscale.enable = true;
flattoo.remote.ssh.enable = true;
flattoo.admin.sshKeys = [ "ssh-ed25519 AAAA… lee@desk" ];
```

sshd then listens only on the Tailscale interface, key auth only, `lee`
only. First time: `sudo tailscale up` on the laptop and approve it in the
admin console.

## Moving to a new laptop

Build the ISO, run `flattoo-install`, done. Home directory: copy
`/home/artist` across with `rsync -a` from the old disk (or LocalSend for
the few folders that matter). The Nix side carries nothing machine-specific
except `hardware-configuration.nix`, which the installer regenerates.

## Upgrading NixOS releases

Twice a year nixpkgs moves on (26.11 in November 2026). Change the channel
in `flake.nix`:

```nix
nixpkgs.url = "https://channels.nixos.org/nixos-26.11/nixexprs.tar.xz";
```

`nix flake update`, `nix flake check`, read the release notes for renamed
options (the evaluator names each one), bump `system.stateVersion` only
if the notes say to, push. The laptop picks it up that night.
