---
id: safety
title: What the laptop does to stay safe
summary: The disk is encrypted, the firewall is closed, updates are automatic, and on strange Wi-Fi the laptop ignores anything trying to redirect it. In plain words.
category: safety
order: 22
tags: [safety, security, safe, encrypted, firewall, virus, hacked, public wifi, privacy, tracking]
questions:
  - is this laptop safe
  - do I need antivirus
  - is it safe on public wifi
  - what if it gets stolen
actions: []
menu: []
screenshots: []
related: [internet, updates, lock-setup, lock-screen]
---
- **If it is stolen:** the disk is encrypted. Without the passphrase, the drawings and everything else are unreadable. That is why the passphrase is asked at power-on.
- **Viruses:** there is nothing to install from the internet by double-clicking, and no antivirus to keep up to date. Apps come only from Ask Flattoo's list. Firefox blocks ads and trackers.
- **Updates:** security fixes arrive every night by themselves. [Updates](updates.html).
- **Public Wi-Fi:** the laptop ignores anything on the network that tries to redirect it, pretend to be the router, or answer in the router's place. Name lookups go encrypted to a fixed, trusted service and are checked for forgery. Firefox only talks to secure sites. The one exception is a Wi-Fi login page, which the laptop allows for exactly as long as it takes to log in.
- **Private things stay private:** nothing about the laptop's network is sent anywhere, the laptop does not announce its name to the Wi-Fi, and it uses a different hardware address on every network so it cannot be followed between them.
- **Nobody can get in:** nothing on the laptop accepts connections from outside unless Lee turns on remote maintenance, and that goes through an encrypted tunnel with keys at both ends.
- **Lee's changes are checked:** setup changes are fetched from a known place; with signing turned on, the laptop refuses anything not signed by Lee's key.

What you still do: keep the passphrase to yourself, lock the screen when you walk away (close the lid), and be as skeptical of emails as anywhere.
