# Changelog

## 0.1.4 (2026-11-11)
- Controller type detection: the addon now reads the connected gamepad's USB vendor id and Blizzard's own button-label style (`C_GamePad.GetDeviceRawState` / `GetDeviceMappedState`) to identify PlayStation, Xbox, Nintendo Switch and Valve/Steam Deck pads; unknown pads report their ids in `/ubermoc debug`.
- New "Controller Type" dropdown on the addon's settings page (Auto-detect / PlayStation / Xbox / Nintendo Switch / Steam Controller / Generic), a native Blizzard dropdown control.
- `/ubermoc` now prints the detected controller name and type, e.g. "Controller connected: Steam Deck - Steam".
- Esc-menu now also gets an "Ubermoc Keybinds" entry next to "Ubermoc", so key bindings are reachable from the pause menu with a controller.
- Esc-menu button callbacks now close the menu exactly like Blizzard's own buttons (`HideUIPanel(GameMenuFrame)`), which keeps the rest of the menu, including Exit Game, working normally.
- Controller state refreshes on `GAME_PAD_CONNECTED` / `GAME_PAD_DISCONNECTED` / `GAME_PAD_ACTIVE_CHANGED` / `ACTIVE_GAME_MODE_UPDATED`, so hot-swaps on Deck are tracked.

## 0.1.3 (2026-11-11)
- Added a way to reach keybindings: `/ubermoc keybinds` and an "Open the Keybindings page" row on the addon's settings page jump straight to the game's own Keybindings settings, where keys and controller buttons are configured.
- Deep audit fixes: controller presence now uses the real device APIs (`C_GamePad.GetActiveDeviceID` / `GetAllDeviceIDs`) instead of the gamepad-support setting, so "Controller connected" is accurate with no pad plugged in.
- Esc-menu button is now added through Blizzard's own menu builder (`GameMenuFrame:AddButton` hook) so it lays out and navigates like native entries instead of a fixed-offset frame.
- Settings panel now binds all options to the single SavedVariables table, so changes always persist.
- Fixed the Esc-menu button disappearing after the first time the menu was opened (a leftover "added once" flag; Blizzard rebuilds the menu every time it opens).
- Removed invalid `OptionalDeps` entry, stale comments and dead code; added `debug` to saved defaults.

## 0.1.1 (2026-11-10)
- Fixed duplicate defaults and duplicate slash command definition.
- Implemented multi‑handler event system to allow both core and options to register `ADDON_LOADED`.
- Added guard for nil `ns.db` in slash command.
- Added controller detection to avoid false "Controller input enabled" messages.
- Added Settings checkbox for enabling/disabling controller input.
- Updated .toc version.
