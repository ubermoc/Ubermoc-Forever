# Changelog

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
