# Changelog

## 0.1.1
- New command `/ubf padtest` shows a live readout of the active controller: which buttons are held, which axes move, and the sticks. Press `/ubf padtest` again to hide it.
- Button and axis names are shown for both index bases, because Blizzard's docs don't say which one the lookups use. This will settle it from your real hardware.
- `/ubf pad` now puts a space before "(active)" and "(combined)".

## 0.1.0
- Added controller detection. The addon now lists every controller the game sees, which one is active, its button-label style and its button, axis and stick counts.
- New command `/ubf pad` prints that report. Please send me its output from your Steam Deck and from your Steam Controller setup, so the layouts are built from what the game really reports.
- The addon now notices when a controller is connected, disconnected or switched, and logs it.

## 0.0.2
- Fixed: releases now also publish a GitHub Release with the zip attached, not just the CurseForge file.

## 0.0.1
- First scaffold: addon loads on World of Warcraft: Forever (TOC 16001) and Midnight (TOC 120105).
- `/ubf` command with `debug`, `log` and `version`.
- Error log that records Lua errors from this addon.
- Warns once at login if Ubermoc UI is also enabled, since both bind the gamepad.
