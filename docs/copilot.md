# Ask Flattoo (the copilot)

The artist never sees a terminal. Everything that would be one — installing
an app, updating, fixing the printer, freeing disk space — goes through
**Ask Flattoo**: the speech-bubble button next to the menu, `Super+Space`,
or the "Ask Flattoo" menu entry. Type what you want in plain words:

| You type | What happens |
|---|---|
| *something like Microsoft Paint* | Shows the drawing apps that fit (AzPainter, Drawing, Krita, MyPaint, Pinta), says which are already installed, with a note if one is too heavy for this laptop. Pick one → Open, or Install. |
| *photoshop* | Krita and GIMP — the two that cover that ground here. |
| *install pinta* / *get me spotify* | Confirms, installs, tells you it is in the menu. |
| *remove blender* | Removes an app that was added this way (base apps stay). |
| *open krita* / *put inkscape on the panel* | Does that. |
| *update now* / *security updates* | Runs the update now (it also happens every night). |
| *when did it last update* | Shows the last run and the version. |
| *the printer isn't working* | Runs **Fix Stencil Printer**. |
| *bluetooth printer* / *printer on wifi* | Opens the pairing or network setup. |
| *prints too small* | Prints the calibration page. |
| *print a stencil* | Opens **Print as Stencil**. |
| *running out of space* / *free up space* | Shows free space, offers to remove old system versions (keeps two weeks for rollback). |
| *wifi* / *bluetooth* / *battery* | Status and the matching settings window. |
| *send photos from my phone* | LocalSend. |
| *turn off* / *restart* / *log out* | The shut-down dialog. |
| *screen too dark* / *second screen* | Display settings (and where the brightness keys are). |
| *dark mode* / *bigger text* / *theme* | Opens **Looks**. |
| *side by side* / *layout* | Opens **Layouts**. |
| *lock this setup* | Opens **Lock This Setup**. |
| *how do I scan a sketch* / *what is the lock screen password* / *where did my file go* | Opens the matching page of **Help & How-To** ([docs/wiki.md](wiki.md)); several close pages → a list to pick from. |
| *what can you do* | Lists all of the above. |

Anything else gets "I don't know how to do that" and the list. Nothing is
changed without a confirmation dialog that says what will happen.

## Why it is safe to hand to a non-technical user

The copilot is **not** a chat window to a shell. It is a fixed menu of
actions with a natural-language front end:

* **Allowlist, not interpretation.** A request becomes exactly one of
  twenty-odd actions (`install`, `remove`, `open`, `panel`, `suggest`,
  `update`, `update-status`, `printer-*`, `print`, `disk`, `wifi`,
  `bluetooth`, `battery`, `power`, `display`, `look`, `layout`, `lock`,
  `installed`, `learn`, `help`). `learn` opens a wiki page; its page id is
  validated against the wiki index.
  There is no action that takes a command string. `rm -rf /` is answered
  with the help text.
* **Catalog-only installs.** `pkgs/flattoo-copilot/share/flattoo/catalog.json`
  is the complete list of what can be installed: ~40 curated apps with
  plain-English tags (`ms paint`, `lightroom`, `consent form`, `send from
  phone`…), hardware hints (`min_ram_gb`, `gpu`, `heavy`) and which are in
  the base image. The CI check `copilot-catalog` proves every entry is a
  real package in the pinned nixpkgs.
* **Declarative installs.** Installing writes
  `hosts/<host>/apps.nix` = `{ flattoo.apps.extra = [ "pinta" ]; }` and
  rebuilds. The NixOS module (`modules/copilot.nix`) refuses any name that
  is not in the catalog **at evaluation time**, so even a hand-edited
  `apps.nix` cannot pull in arbitrary software. Added apps survive nightly
  upgrades (see *Upgrades* below) and are listed by *what apps do I have*.
* **One privilege boundary.** The only thing that runs as root is
  `flattoo-admin`, reached through polkit action `org.flattoo.admin`
  (members of group `flattoo` in an active local session; anyone else
  needs the admin password). It has four subcommands — `install PKG…`,
  `remove PKG…`, `update`, `cleanup` — validates `PKG` against the catalog
  itself, and logs to `/var/log/flattoo-admin.log`. Everything else the
  copilot does runs as the artist (opening apps, panel launchers, the
  existing stencil/look tools).
* **Optional LLM, understanding only.** `flattoo.copilot.llm.provider` is
  `none` by default: the built-in matcher (synonyms, catalog tags, fuzzy
  spelling) handles the table above and is tested on every build
  (`copilot-matcher`). Set it to `anthropic` (API key in
  `/etc/flattoo/copilot.key`, mode `0640 root:flattoo`, not managed by
  Nix) or `ollama` (local model; slow without a GPU) to understand odd
  phrasings. Either way the model returns `{action, args, say}` and that
  JSON is validated against the same allowlist and catalog — an action or
  package it invents is dropped and the rules take over. The model never
  sees a shell.

## Upgrades, and why local apps are not lost

`flattoo-sync` (`modules/autoupgrade.nix`) runs before every nightly
`nixos-upgrade` and before `flattoo-admin update`. It mirrors
`github:LeeLupton/Flattoo` into `/etc/nixos` with `rsync --delete`,
**keeping this machine's own files**: `hardware-configuration.nix`,
`passwords.nix`, `apps.nix`, `look.nix` and `look/`. The system is then
built from `/etc/nixos`. So a push to `main` still lands on the laptop
the next night, and the apps the artist added — or the look they locked —
ride along. Offline, the sync fails harmlessly and the local copy is
rebuilt as is.

When the setup is **locked** (`/etc/flattoo/locked`), `flattoo-sync` does
nothing: the repo is no longer pulled from GitHub, only nixpkgs moves
(weekly `flattoo-nixpkgs-update`), so security fixes keep flowing while
the configuration is frozen. **Unlock** resumes the mirror.

## Files

```
pkgs/flattoo-copilot/bin/flattoo-copilot          the copilot (Python, zenity GUI + CLI, --dry-run)
pkgs/flattoo-copilot/bin/flattoo-admin            the root helper (bash, 4 subcommands)
pkgs/flattoo-copilot/share/flattoo/catalog.json   what can be installed
pkgs/flattoo-copilot/share/polkit-1/actions/      org.flattoo.admin
pkgs/flattoo-copilot/tests/matcher_test.py        phrasings → actions; LLM-output validator
modules/copilot.nix                               flattoo.copilot.*, flattoo.apps.extra, polkit rule
hosts/<host>/apps.nix                             written on the machine; kept across syncs
```

Try it from a shell: `flattoo-copilot --dry-run "something like paint"`
prints the action it would take and changes nothing.

## Adding to the catalog

Add an entry to `catalog.json`: `pkg` (nixpkgs attribute, dotted paths
allowed: `kdePackages.kdenlive`), `name`, `category`, `tags` (how the
artist would ask for it — brand names they know are good tags), `blurb`
(one sentence, no jargon), optional `suite`, `min_ram_gb`, `gpu`
(`"recommended"`), `heavy`, `default` (already in the base image),
`desktop` (the `.desktop` file, for Open and the panel). Push; CI checks
the name exists and the matcher still passes.
