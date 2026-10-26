---
id: fix-printer
title: The printer is not working
summary: Fix Stencil Printer re-detects the printer over USB, Wi-Fi and Bluetooth and clears stuck jobs. No password.
category: printing
order: 12
tags: [printer not working, fix printer, won't print, not printing, printer broken, printer missing, no printer, stuck job, jam]
questions:
  - the printer isn't working
  - the printer won't print
  - nothing comes out
  - the printer disappeared
actions: [printer-fix]
menu: [Fix Stencil Printer]
screenshots: [fix-printer]
related: [printer-usb, printer-bluetooth, printer-wifi, calibrate]
---
Ask Flattoo "the printer isn't working", or open **Fix Stencil Printer** from the menu. It:

1. looks for the printer over USB, then on the Wi-Fi, then over Bluetooth;
2. rebuilds the **Stencil** printer with the right settings;
3. clears any job that was stuck;
4. tells you what it found, or that it found nothing.

## If it found nothing

- Is the printer **on**? Thermal printers go to sleep; turn it off and on.
- **Cable:** try another USB port, and the printer's own cable.
- **Bluetooth:** is the printer within a few meters and blinking ready? Pair again with [Add Bluetooth Stencil Printer](printer-bluetooth.html).
- **Wi-Fi:** is the laptop on the same Wi-Fi as the printer? [Network printer](printer-wifi.html).

## Prints, but wrong

- **Blank or very light sheet:** paper in upside down, or the wrong paper. Thermal stencil paper has a coated side; it goes face up in a PocketJet, as the lid diagram shows.
- **Faint lines:** in Print as Stencil choose **Crisp black lines**, not **Keep shading**.
- **Wrong size:** print the [calibration page](calibrate.html).
- **Mirrored:** Mirror should be No for stencil paper.
