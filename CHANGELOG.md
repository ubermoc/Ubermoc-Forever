# Changelog

## 0.2.2 (2026-11-12)
- **Default key layout fixed — it now starts on the main bar and runs clockwise.** Before, each button's Shift/Ctrl layers went to the same *slot number* on the next bars, so X landed on action bar 2's bottom-left slot instead of its 3:00 position. Now every button keeps its own clock position on every bar: A is at 3:00 on all four bars, Y at 12:00, B at 9:00, X at 6:00; the D-pad runs clockwise from up; and the triggers/bumpers form one clockwise group (right trigger 3:00, right bumper 6:00, left trigger 9:00, left bumper 12:00 on the main bar). Bumpers still target nearest enemy/friend. Players who applied the old defaults are asked once whether to update to the new layout — nothing changes unless they accept (`/ubermocbinds restore` still puts their original keys back).
- **Steam Deck / Steam Input controllers are now detected.** The addon trusted only the game's device list, which on the Deck is often empty until the virtual pad gains gamepad focus — so it kept reporting "no controller". It now also asks the client for its active and combined gamepad devices and probes device ids directly, recognises a Steam-Input pad that reports no USB ids (using the mapped name and label style), and re-checks when the game's input mode changes or after combat. `/ubermoc devices` now lists every id source separately (list / active / combined / probe) so a Deck pad invisible to one API but visible to another can be told apart.

## 0.2.1 (2026-11-12)
- Fixed the error popup when clicking **Exit Game** (or Logout) in the Esc menu. Opening the settings page from an "Ubermoc" menu entry used to happen inside Blizzard's own "panel hidden" dispatch; the settings window's open path hides the pause menu again, which re-entered that same dispatch and made the game try to re-show the menu while it was being torn down for quit/logout. The settings open now happens one frame later, outside Blizzard's dispatch, and a recorded menu choice is cancelled if a quit or logout starts.

## 0.2.0 (2026-11-12)
- Controller button bindings now actually fire. The addon used to place its button claims on the game's shared top-level frame and wipe that whole frame every time bindings were rebuilt — which also erased the game's own controller bindings, and the game then re-placed its claims over ours, so our buttons did nothing. Claims now live on a frame of the addon's own: rebuilding only ever touches the addon's bindings, and whenever anything else re-claims a button the addon owns, it quietly puts its claim back on top.
- Default bindings moved off the triggers and bumpers (right/left trigger, right/left shoulder): while the game's controller cursor mode is on, the client itself uses those buttons for mouse clicks and Ctrl/Shift emulation, so defaults there fought the client. New defaults sit on the face buttons, d-pad and stick clicks; your own rebinds are kept. Buttons your pad does not physically have (e.g. back paddles) are no longer bound or claimed at all — they drop out while an unsuitable pad is connected and return when a suitable one connects.
- New diagnostic: `/ubermoc devices` prints exactly what the game sees — every gamepad device with its name, vendor/product ids, button and axis counts. If your Steam Deck pad "is not picked up", run this and check the list: if it's empty, the game is not receiving controller buttons at all (the game's Controller settings in Steam must use a plain Gamepad layout, not one that sends keyboard keys).
- When no controller is seen, `/ubermoc` now points at that setting instead of just saying "no gamepad device seen".

## 0.1.9 (2026-11-12)
- Fixed "attempt to call a nil value" error that fired when opening the settings page. The binding rows are recycled by Blizzard's scroll list every time the page opens or is searched, and the recycle step asked each stock binding button whether it was "selected" — a method those buttons don't have (they track listening state differently). Rows now ask the button whether it is currently waiting for a binding, which is the real question, so a half-finished capture is still cancelled safely without the error.

## 0.1.8 (2026-11-12)
- Fixed the "AddOn 'UbermocForever' tried to call the protected function 'callback()'" popup when clicking an Ubermoc entry in the Esc menu. The pause menu closes through a protected Blizzard call, and anything our button callback did inside that flow was blamed on the addon. The menu entries are now inert: they only record which entry was chosen, and the settings page opens from Blizzard's own "panel hidden" callback once the menu has closed — same result, no protected-call violation.

## 0.1.7 (2026-11-12)
- The bindable action list grew from 8 to 31 actions, grouped like the stock keybinding page: targeting (next enemy / friend / party member / enemy player, clear target, focus, interact), combat (attack toggle, stop casting, ready check, ping target), movement (jump, auto run, mount/dismount, camera zoom) and windows (bags, character, spells, talents, map, quest log, social, mount journal, group finder). Every window toggle calls exactly the function Blizzard's own binding table runs for that key, so a bound pad button behaves like the stock keyboard shortcut.
- Right-click now clears a binding everywhere on the row — on the label and on the binding button itself (the old handler never received the click because the stock button consumed it).
- While a row is listening, pressing a controller button performs that action immediately as a live preview before the binding is stored, so you can confirm what the button does.
- Removed the "Enable UbermocForever" and "Enable controller input" checkboxes: with the addon installed, both are always on. `/ubermoc toggle` is gone too.
- Better device naming: pads routed through Steam Input (Steam Controller / Steam Deck virtual gamepads) are now recognised by device name when their USB vendor id is missing or unknown; a pad that still can't be named prints its vendor/product ids in chat so support can be added.
- Searching the bindings page for a button name (e.g. "paddle") now also matches rows that could take that button, not just rows already bound to it.

## 0.1.6 (2026-11-12)
- Controller Bindings are now a real section on the addon's own settings page: each action gets a stock Blizzard binding button (`CustomBindingButtonTemplate` through `CustomBindingManager`, the game's own system for add-on-owned bindings), sitting in the same scrolling, searchable list as every other option. Nothing is custom-drawn — button art, fonts and selection highlight are all stock.
- Click a binding button (mouse or controller) to listen, then press a controller button to bind it; chords of two buttons work. Non-controller input is rejected with a message. Right-click the row's label to clear a binding. The panel's bottom status line shows the "press a button" prompt while listening, like the stock keybinding page.
- The Esc-menu "Ubermoc Keybinds" entry now opens the addon's settings page scrolled straight to the Controller Bindings section instead of jumping to the generic Keybindings page.
- New slash commands: `/ubermoc bind <action> <PADBUTTON[-PADBUTTON]>` and `/ubermoc unbind <action>` (the old fake "Bind:" checkbox rows are gone; `bindlist` and `bindreset` unchanged).

## 0.1.5 (2026-11-11)
- Controller button bindings now work: each action is bound through the game's own binding system (override click bindings on hidden secure buttons that run `/ubermoc click <action>`), so no synthetic input is produced and Blizzard's bindings stay untouched.
- Default bindings: left bumper = toggle controller mode, right bumper = open settings, face buttons and triggers = Actions 1–6 (placeholders for now).
- Rebind from the addon's settings page: each action has a "Bind:" row — tick it, then press any controller button to capture it (`OnGamePadButtonDown` listener, enabled only while capturing). `/ubermoc bind <action>`, `unbind`, `bindlist`, `bindreset` do the same from chat.
- Button labels follow the connected pad: the client reports a label style per device (Generic / Letters / Shapes / Reverse) and Blizzard's own icon strings are used, so Steam Deck, Steam Controller, PlayStation, Xbox and Switch pads show their native button art. The "Controller Type" dropdown also overrides the label style; `/ubermoc setstyle auto|playstation|xbox|switch`.
- Settings page now shows a live "Controller detected" readout (device name and label style) that updates on connect/disconnect.
- Binding changes attempted during combat are deferred and replayed when you leave combat (`InCombatLockdown` guard).

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
