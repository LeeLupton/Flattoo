# Maintenance

## The update pipeline

1. The weekly GitHub workflow runs on Mondays at 09:17 UTC. It updates the
   lock file, evaluates both hosts, runs the stencil round-trip test, and builds
   the PJ-723 wrapper before pushing a changed lock file to `main`. Validated
   configuration edits can also be committed and pushed to the update source.
2. The laptop's timer is scheduled for 03:30 in its configured time zone
   (`America/New_York` by default), plus up to 45 minutes of randomized delay.
   A missed run is caught up after the next boot. The default update command is
   `nixos-rebuild boot --flake github:LeeLupton/Flattoo#shop-laptop --refresh`.
3. A successful build becomes the default for the following boot. It does not
   activate in the running session, and the job never reboots the laptop.

Properties:

* Nothing is ever half-applied. A failed build leaves the running system
  untouched; the nightly timer tries again tomorrow.
* The build runs at `Nice=15` / idle IO with reduced CPU weight to give
  interactive work priority when the timer fires during a session.
* Up to fourteen generations are listed in the boot menu; `nix-collect-garbage`
  runs weekly and removes anything older than 21 days.
* Only `cache.nixos.org` is trusted as a binary cache, with its key pinned.

## Day to day

For administration on the installed laptop, log in as `lee` or use `su - lee`
from a terminal and enter the admin password. The artist account has no sudo.
Run repository checks from the root of your development checkout on x86_64
Linux with Nix's `nix-command` and `flakes` features enabled.

| Task | Command |
|---|---|
| Evaluate the flake without building checks | `nix flake check --no-build` |
| Build and run all declared checks | `nix flake check --print-build-logs` |
| Apply the local installation copy and its edits | `sudo nixos-rebuild switch --flake /etc/nixos#shop-laptop` |
| Apply now from the GitHub copy | `sudo nixos-rebuild switch --flake github:LeeLupton/Flattoo#shop-laptop --refresh` |
| See the recent upgrade log | `sudo journalctl -u nixos-upgrade.service -n 100 --no-pager` |
| Inspect the upgrade timer | `systemctl status nixos-upgrade.timer` |
| Activate the previous system-profile generation | `sudo nixos-rebuild switch --rollback` |
| Which printer queues exist | `lpstat -v` |
| Recreate the Stencil queue | `sudo stencil-queue-setup` |
| Print a stencil from the shell | `stencil-print --width 3.5 design.png` |
| Format all tracked Nix files (in a Git checkout) | `nix fmt -- $(git ls-files '*.nix')` |

The installer leaves `/etc/nixos` as a source snapshot with generated hardware
configuration and initial account password hashes. It is not a Git checkout;
`git pull` does not update it. Nightly builds use the remote flake independently,
so they do not pick up local-only edits or refresh this directory. Put persistent
changes in the configured update repository, or change
`flattoo.autoUpgrade.flake` to your fork or `null` for manual updates.

Keep `hosts/shop-laptop/passwords.nix` local and out of Git. Preserve the
generated hardware configuration when refreshing local source, and include
required hardware settings in the repository used for remote updates.

### Choosing checks

The full `nix flake check` also builds the laptop system closure, printer
packages, stencil round-trip test, and simulated Phomemo integration test.
It does not build the installer ISO. For targeted checks, see the
[README validation commands](../README.md#validate-a-repository-change).
The current push/PR workflow evaluates the laptop, runs the stencil round-trip
test, and checks Nix formatting. The weekly workflow adds installer evaluation
and a PJ-723 wrapper build. Neither currently runs the Phomemo integration test.

### Recovering from a bad generation

If an upgrade does not boot, select a known-good earlier generation in the boot
menu. `--rollback` selects the previous **system-profile** generation, which may
differ from the last system you actually booted when nightly builds have staged
several generations. Fix or revert the update source, or disable automatic
upgrades in the applied configuration, before another run stages the unwanted
configuration again. Rollback changes the system generation; it does not restore
artwork or other personal files.

## Adding software

Add the package to the relevant module (`modules/art.nix` for drawing,
`modules/media.nix` for utilities). Search names at
<https://search.nixos.org/packages?channel=26.05>. Push.

## Changing the artist's defaults

* Panel layout: `files/xfce/panel-default.xml` (only seeds a fresh profile;
  existing users keep what they changed).
* Right-click actions: `files/thunar/uca.xml`.
* Screen lock / lid: `flattoo.desktop.lockOnSuspend`, `modules/laptop.nix`.

## Remote access

Off by default. To turn on:

```nix
flattoo.remote.tailscale.enable = true;
flattoo.remote.ssh.enable = true;
flattoo.admin.sshKeys = [ "ssh-ed25519 AAAA… lee@desk" ];
```

With both options enabled, the firewall permits SSH through `tailscale0`;
SSH authentication uses keys and permits only the configured admin (`lee` by
default). First time: `sudo tailscale up` on the laptop and approve it in the
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
