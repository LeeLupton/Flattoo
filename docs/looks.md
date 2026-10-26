# Looks, layouts, and the lock

Customizability is turned up on purpose: the artist should be able to make
the desktop theirs from the menu, then freeze it.

## Looks (`flattoo-look`)

**Looks** in the menu (or the panel) shows whole-desktop presets. Picking one
applies GTK/xfwm theme, icons, cursor, fonts, wallpaper, workspaces and
their names, the panel (position, size, launchers), window behavior and
keyboard shortcuts, live, through xfconf — no logout.

| Preset | Feel |
|---|---|
| **Home** (default) | Phone-style: app icons on the desktop (managed `~/Desktop/*.desktop`, trusted via `metadata::xfce-exe-checksum`), a translucent centered dock (second panel: `xfce4-docklike-plugin` for running apps, big launchers), a slim top status bar (clock left, tray/volume/battery right), WhiteSur-Light GTK/xfwm + WhiteSur icons + WhiteSur cursors, Inter, single-click in Thunar and on the desktop, `titleless_maximize`, mac-style button layout, Super → the rofi app grid (`flattoo-apps`, `share/rofi/apps.rasi`). Familiar app names (`app_names: familiar`): Files, Photos, Scanner, Settings, Notes, Documents/Spreadsheets/Slides, Mail, Messages, Calendar, Calculator — per-user overrides in `~/.local/share/applications`, marked and removed by looks that use standard names. |
| **Home (dark)** | Same, WhiteSur-Dark. |
| **Studio Dark** | Dark grey, cool accents, panel on top. |
| **Paper** | Light, warm, paper wallpaper. |
| **Night Session** | Near-black, autohiding panel. |
| **Big and Simple** | Large icons and text, dock at the bottom. |
| **Classic Desktop** | Windows-style: Fluent-Light GTK/xfwm + Fluent icons, taskbar at the bottom, menu left, clock right, familiar names. |
| **Gruvbox** | Warm retro palette, panel on the left. |

Icon themes are the open-source WhiteSur (Mac-style) and Fluent (Windows
11-style) sets from nixpkgs; the familiar-name overrides point office apps at
the standard `x-office-document/-spreadsheet/-presentation` glyphs, which
those themes draw in the blue/green/orange people expect.

Every preset carries the **Ask Flattoo** button next to the menu and
`Super+Space` for it; `Super` alone opens the menu, `Super+P` prints a stencil, `Super+L` opens layouts.

A preset may carry `panels` (a list; each with `position`, `size`, `icon_size`,
`length`, `length_adjust`, `background` rgba, and `items` — launcher ids,
`apps`, `menu`, `dock`, `tasklist`, `spacer`, `sep`, `tray`, `volume`, `power`,
`clock`, `showdesktop`), `xfconf` (extra `[channel, property, type, value]`
settings), `desktop_launchers` and `app_names`. `flattoo-look panel-tar NAME
out.tar.bz2` shows the generated panel profile.

Touchpad gestures (`flattoo.desktop.gestures`, touchegg): three fingers
left/right change workspace (browser: back/forward), up maximizes, down
minimizes; four fingers up shows the desktop; pinch zooms. Config seeded to
`~/.config/touchegg/touchegg.conf` at first login.

**Save current look** turns whatever the artist has tweaked by hand
(Appearance, Window Manager, Panel settings, `lxappearance`) into a new
preset under `~/.config/flattoo/looks/`.

Themes shipped: Arc, Materia, Dracula, Nordic, Gruvbox, adw-gtk3, Orchis;
icons Papirus, Tela, Numix, Adwaita; cursors Bibata, Capitaine, Phinger.
Fonts: Inter, Roboto, Lato, Montserrat, Work Sans, JetBrains Mono, and a
lettering set — League of Moveable Type, TeX Gyre Chorus (Zapf Chancery),
Cinzel, Old Standard, EB Garamond, Libertinus, Junicode, Vollkorn, Crimson,
Yanone Kaffeesatz, League Gothic, Oswald, Source Serif, IBM Plex, Comic
Neue. Drop more `.ttf`/`.otf` on Font Manager.

## Layouts (`flattoo-layout`)

**Layouts** opens a set of windows and places them:

| Layout | Windows |
|---|---|
| **Drawing** | Krita maximized. |
| **Reference + Draw** | Krita left, the image viewer right for the reference photo. |
| **Sketch to Stencil** | Simple Scan left, Files right; Clean Lines and Print as Stencil are a right-click away. |
| **Web Reference** | Krita left, Firefox right. |
| **Paperwork** | Firefox left, Files right. |

**Save current layout** records the open windows and their positions as a
new layout. Placement is `max`, `left`, `right`, `top`, `bottom`, `full`
or `x,y,w,h` in percent, via `wmctrl`/`xdotool`.

## i3 session

A tiling session for people who want it: at the login screen (visible when
auto-login is off, or after logging out) pick **i3**. Same apps and
helpers: `Super+Space` Ask Flattoo, `Super+D` launcher (rofi), `Super+K`
Krita, `Super+P` stencil print, `Super+L` layouts, `Super+Return` terminal,
`Super+1..9` workspaces. Config:
`pkgs/flattoo-looks/share/i3/config`, validated on every build
(`looks-i3config`). `flattoo.desktop.i3Session = false` removes it.

## Lock This Setup (`flattoo-lock`)

When the artist is happy, **Lock This Setup** (menu, or *lock this setup*
in Ask Flattoo):

1. Exports the current desktop — every xfconf channel, the panel with its
   launchers, saved layouts, Thunar actions, default apps, Krita settings —
   into a bundle (`flattoo-look export`).
2. `pkexec flattoo-lock-apply` (polkit `org.flattoo.lock`, no password for
   the artist) copies the bundle to `/etc/nixos/look`, writes
   `hosts/<host>/look.nix` with `flattoo.locked = true; flattoo.look.bundle = ../../look;`,
   commits, and `nixos-rebuild switch`es.

Locked mode (`modules/locked.nix`) means:

* The bundle is the system default **and** is restored into the artist's
  config before every login — a stray change is gone at the next login.
* xfconf kiosk: panel, desktop and session settings need `wheel`.
* Idle screen lock forced on; boot menu hidden (`timeout 0`; hold a key
  for rollback); Firefox add-on installs and devtools off.
* Upgrades keep coming from the **local** copy: GitHub is no longer pulled
  (see [copilot.md](copilot.md), *Upgrades*), only nixpkgs is bumped weekly
  (`flattoo-nixpkgs-update`, Mondays 02:30) so security fixes land.

**Unlock** (menu; asks for the administrator password, `org.flattoo.unlock`)
flips `flattoo.locked = false`, keeps the bundle as the default look, and
nightly syncs from GitHub resume.

`checks.locked-eval` evaluates the laptop in locked mode with
`tests/look-bundle` on every push.

## Files

```
pkgs/flattoo-looks/bin/flattoo-look          gui | list | current | apply | save | export | restore-files | panel-tar
pkgs/flattoo-looks/bin/flattoo-layout        gui | list | apply | save | validate
pkgs/flattoo-looks/bin/flattoo-lock{,-apply} / flattoo-unlock{,-apply}
pkgs/flattoo-looks/share/looks/*.json        presets
pkgs/flattoo-looks/share/layouts/*.json      layouts
pkgs/flattoo-looks/share/i3/                 i3 config + i3status
pkgs/flattoo-looks/wallpapers/make.py        generated wallpapers (slate, paper, ink, blue, ember, sage)
modules/looks.nix                            themes, fonts, first-login look, i3 session
modules/locked.nix                           the lock
```

Options: `flattoo.look.default` (preset applied at first login),
`flattoo.look.bundle`, `flattoo.locked`, `flattoo.desktop.i3Session`.
