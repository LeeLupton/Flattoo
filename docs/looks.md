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
| **Blackwork** | Monochrome: Graphite-Dark + Qogir-Dark icons, halftone wallpaper, nearly square corners, dock at the bottom. Night twin of Flash Sheet. |
| **Flash Sheet** | Gruvbox-Light + Kora icons on a parchment wallpaper with a draft grid and the traditional palette as a test strip; one top panel with a window list, familiar names. |
| **Neon** | Tokyonight-Dark + Nordzy purple icons, neon-tube wallpaper, the dock down the left edge, unfocused windows at 94 % opacity. |
| **Sakura** / **Sakura Night** | Rosé Pine Dawn / Moon GTK+xfwm, Nordzy pink icons, BreezeX Rosé Pine cursors, petal wallpapers, 16 px corners; the night twin warms the screen to 4300 K. |
| **Forest** | Everforest-Dark + Nordzy green icons, misty ridgeline wallpaper, one bottom panel with a window list, standard app names. |
| **Kanagawa** | Kanagawa-B + Nordzy cyan icons, wave wallpaper, dock at the bottom. |

All wallpapers (gradients, halftone, parchment grid, neon glow, petals,
ridgelines, waves) plus the boot mark and the lock backdrop come out of
`pkgs/flattoo-looks/wallpapers/make.py` at build time — numbers in, pixels
out, nothing to clear rights on.

Icon themes are the open-source WhiteSur (Mac-style) and Fluent (Windows
11-style) sets from nixpkgs; the familiar-name overrides point office apps at
the standard `x-office-document/-spreadsheet/-presentation` glyphs, which
those themes draw in the blue/green/orange people expect.

Every preset carries the **Ask Flattoo** button next to the menu and
`Super+Space` for it; `Super` alone opens the menu, `Super+P` prints a stencil,
`Super+L` opens layouts, `Super+Escape` opens the power sheet.

### Effects, palette, night light, night twin

Beyond theme/icons/panel, a preset can carry:

- `effects` — `{"corners": 12, "shadows": true, "blur": true, "animations":
  true, "fade": true, "inactive_opacity": 1.0, "shadow_opacity": 0.35,
  "shadow_color": "#000000"}`, or `false` for xfwm's own compositor.
  `flattoo-look` turns it into `~/.config/flattoo/picom.conf` (GL) and
  `picom-xrender.conf` (no blur) with window rules: a centred dock floats
  (rounded, shadow, blurred), a full-width bar stays square, menus and
  tooltips get small radii, fullscreen windows, the screensaver and xfwm's
  own popups get nothing. `flattoo-compositor start|restart|off|status`
  manages picom: GL first, the xrender variant when GL cannot start (a VM,
  a driver without GLX), xfwm compositing back on when neither can. An
  `flock` serialises the autostart entry and the first-login seed. `flattoo-look
  effects on|off` and Looks → "Window effects" toggle per user;
  `flattoo.desktop.effects = false` leaves picom out of the system.
  `flattoo-look picom-conf NAME [--xrender]` prints the config a look makes;
  `checks.looks-effects` starts picom with every one of them under Xvfb.
- `palette` — `bg, fg, muted, accent, on_accent, border, card, rofi_bg,
  radius`. Written at apply time into an xfce4-notifyd theme
  (`~/.local/share/themes/Flattoo/xfce-notify-4.0/gtk.css`) and a rofi
  fragment (`~/.config/flattoo/rofi-colors.rasi`, with the look's icon theme)
  that `flattoo-apps` and `flattoo-power` pass as `-theme-str`. So bubbles,
  the app grid and the power sheet follow the look.
- `notify` — `{"position": "top-center", "opacity": 0.96, "theme": …}`
  (`xfce4-notifyd` `/notify-location`, `/initial-opacity`, `/theme`; the
  theme defaults to the palette's).
- `night_light` — kelvin for a one-shot `redshift -P -O`; a look without it
  resets to neutral, so colour judgement on reference photos is safe by default.
- `night` — the name of the look's dark twin.
- `dark` — whether the look is dark. Mirrored into gsettings
  (`org.gnome.desktop.interface color-scheme`, `gtk-theme`, `icon-theme`,
  `cursor-theme`, `font-name`) so GTK4/libadwaita apps that ignore xsettings
  follow the look too (`programs.dconf.enable`).

Applying a look also writes a softened, dimmed copy of its wallpaper to
`~/.cache/flattoo/backdrop/backdrop.png` and points xfce4-screensaver at the
`flattoo-backdrop` theme (the slideshow helper with that one picture), so the
idle and lock screens show the look's wallpaper instead of black. The shop
display, when on, takes precedence; turning it off returns to the backdrop.

`flattoo-look apply` also records `~/.config/flattoo/current-look`;
`current-name` prints it, `twin NAME dark|light` resolves the pair.

### Automatic night look (`flattoo-look schedule`)

`schedule set 20:00 07:00 | on | off | status | gui | daemon | tick`. The
daemon runs from an autostart entry (`flattoo.desktop.nightSchedule`) and
checks the clock every 30 s; it only acts while `~/.config/flattoo/schedule.json`
says `enabled`. At the night time it applies the day look's `night` twin
(the whole look, so the palette, bubbles and effects change too); a day
look without a twin keeps its colours and gets a warm screen (3800 K); in
the morning the day look comes back. A look picked by hand becomes the day
look unless it is just the current twin. `schedule tick --now HH:MM --dry-run`
says what the daemon would do — that is how `checks.looks-presets` tests it
without a display. Ask Flattoo understands "dark mode at 9pm", "night look
from 20:30 to 7", "stop the automatic night look".

### Shop display and Show a Client (`flattoo-showcase`)

- `flattoo-showcase display on|off|status|gui` — xfce4-screensaver's
  slideshow helper (`libexec/xfce4-screensaver/slideshow`) as the idle
  screen, pointed at the newest `~/Portfolio/<date>/web` or a chosen folder
  (`~/.config/flattoo/display.json`). Installed as a screensaver theme
  (`share/applications/screensavers/flattoo-showcase.desktop`, id
  `screensavers-flattoo-showcase`); `on` sets `/saver/mode 1` and the theme
  list, `off` returns to blank. The lock settings are untouched.
- `flattoo-showcase client [FOLDER]` / `gui` — feh full-screen, auto-advance
  8 s, tap = next, right button = back, wheel = zoom, with a private feh
  `keys`/`buttons` config that unbinds everything destructive (delete,
  remove, save, actions, the menu). Do-not-disturb is set for the
  duration. When feh exits (Esc) the screen locks (`xflock4` →
  `xfce4-screensaver-command --lock` → `loginctl lock-session`). No gallery
  yet → offers to run Portfolio.

### Power sheet (`flattoo-power`)

A rofi dmenu (`share/rofi/power.rasi`, palette from the look): Lock, Sleep,
Restart, Shut down, Log out, with icons; restart/shut down/log out confirm
once. XFCE: `xflock4` and `xfce4-session-logout --suspend|--reboot|--halt|
--logout`; i3: `systemctl` and `i3-msg exit`. Bound to `Super+Escape` in
every look and in the i3 config; the Home looks put it at the right end of
the status bar (`powersheet` panel item); Ask Flattoo "turn off" opens it.

### Boot splash and login screen

`flattoo.desktop.bootSplash` (default on): plymouth's `spinner` theme with
`flattoo-mark.png` as the watermark, `quiet`, `udev.log_level=3`,
`vt.global_cursor_default=0`, `boot.initrd.verbose = false`; the LUKS
passphrase is asked on the splash. `flattoo.desktop.loginScreen` (default
on): LightDM's slick greeter on `lockscreen.png` (the ink gradient with the
mark), WhiteSur-Dark, Inter, clock, no hostname. Auto-login skips it; it
shows after a log-out, for the maintainer account, and for a second session.

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

Themes shipped: WhiteSur, Fluent, Arc, Materia, Dracula, Nordic, Gruvbox,
adw-gtk3, Orchis, Graphite, Tokyonight, Rosé Pine, Everforest, Kanagawa;
icons WhiteSur, Fluent, Papirus, Tela, Numix, Adwaita, Qogir, Kora, Nordzy;
cursors WhiteSur, Bibata, Capitaine, Phinger, Graphite, Rosé Pine, Nordzy,
Volantes.
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
