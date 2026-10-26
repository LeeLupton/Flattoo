# Assist: what the laptop offers to do, and the rules it keeps

`modules/assist.nix`, `pkgs/flattoo-assist`. On by default. The idea: a
working artist has a professional image to keep up — a portfolio, a résumé,
listings that go stale — and no time. The laptop can do the mechanical part.
It must never do the judgment part, and it must never act in the artist's
name.

## Principles (baked in, not configurable)

1. **Offer, don't act.** Every feature starts from a click or an Ask Flattoo
   request, shows what it will do, and asks. The weekly nudge is a
   notification that says; it never does.
2. **Nothing leaves the laptop.** No uploads, no posts, no API calls, no
   scraping of social accounts or review sites. The exposure checklist is
   dates the artist records, not surveillance of their accounts.
3. **Originals are sacred.** Portfolio writes copies into `~/Portfolio/<date>/`;
   it never moves, renames or edits a source file.
4. **Strip what identifies clients.** Every exported copy is re-encoded
   from pixels: no camera, date or GPS metadata survives. A client's living
   room must not be geolocatable from a healed-tattoo photo.
5. **Consent is the artist's call, and the tool says so.** The guided flow
   asks for only clients who agreed to be shown; it cannot know, so it never
   decides.
6. **Plain words, no pressure.** Nudges are one notification a week at most,
   three items at most, and say what to do in the artist's own tools.

## Tools

| Tool | Does | Output |
|---|---|---|
| `flattoo-portfolio` | Finds candidate photos (≥1000 px long edge, not screenshots/stencils, perceptual-hash dedupe) in Pictures, Downloads, Desktop, Documents; guided checklist; builds the gallery | `~/Portfolio/<date>/{web,square,thumbs}/`, `index.html`, `contact-sheet.pdf`, `README.txt`, `manifest.json` |
| `flattoo-profile` | Profile facts (`~/.config/flattoo/profile.json`): name, studio, city, since, bio, skills, certifications with expiry, awards, links; exposure checklist with last-updated dates; weekly nudge | `~/Documents/Artist Profile/resume.html`, `resume.docx` (python-docx), `bio.txt` |

Copilot actions: `portfolio`, `profile`, `profile-skill` (`"add fine line to
my skills"` → `flattoo-profile add-skill`, sanitized, confirmed), `exposure`.

Weekly nudge: `systemd.user` timer `flattoo-assist-remind` (`flattoo.assist.reminderTime`,
default `Mon 10:30`), notification via `notify-send`. Triggers: certification
expiring within 60 days or expired, listing not touched in 45 days, ≥8 new
photo candidates since the last gallery, empty profile.

## Tests

`checks.assist-offline`: synthetic photos (big/small/duplicate/screenshot/
stencil) → scan finds exactly the finished ones; build produces resized,
square and thumbnail copies **with no EXIF**, the gallery page, the contact
sheet; status counts new candidates; profile set/add-skill (dedupe,
sanitizing)/add-cert/render (html, docx, bio); nudges fire for an expired
certification and stale listings; `touch` marks a listing updated.

## Options

```
flattoo.assist.enable          (true)
flattoo.assist.reminders       (true)   weekly notification
flattoo.assist.reminderTime    ("Mon 10:30")
```
