---
id: updates
title: Updates, and going back if one misbehaves
summary: Updates install themselves overnight and take effect at the next power-on. Ask Flattoo "update now" to do it sooner. The previous version is always one boot-menu entry away.
category: system
order: 16
tags: [update, updates, upgrade, security, patch, new version, rollback, go back, last update, boot menu]
questions:
  - how do I update
  - when did it last update
  - something changed after an update
  - how do I go back to how it was
actions: [update, update-status]
menu: [Ask Flattoo]
screenshots: [ask-flattoo]
related: [ask-flattoo, lock-setup, troubleshooting]
---
## How updates arrive

Every night around 3:30 (or when the laptop is next on), it fetches the latest setup and security fixes and builds the new version in the background. **Nothing changes while you work.** The new version starts at the next power-on.

Ask Flattoo **"update now"** to do it right away — a few minutes, keep the laptop plugged in. **"When did it last update"** shows the date and whether it worked.

## Going back

Every version is kept. If something is wrong after an update:

1. Restart.
2. When the laptop starts, a short menu shows for two seconds. Press any arrow key to stop it, pick the entry below the top one (yesterday's version), Enter.
3. Tell Lee which date you went back to.

Nothing is lost by going back; your files are untouched either way. Disk space for old versions is cleaned up automatically after two weeks (or ask Flattoo "free up space").

## Why it is safe

An update is never half-applied: it is built completely first, then switched on at boot. If the build fails, nothing changes and it tries again tomorrow.
