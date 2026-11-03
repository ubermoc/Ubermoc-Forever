# Changelog

## 0.4.0
- New options window, opened with `/ubf options`. Controller only: d-pad moves and changes values, A selects, B or Start closes, L1 and R1 change page.
- Buttons page: turn the layout on or off, press A on a slot and then the button you want for it, reset to defaults.
- Modifiers page: choose which paddles act as Shift and Ctrl, and which action bar each modifier set uses.
- Other page: choose what Start, Select, L3, L4 and L5 do, run the self test, close.
- Binding a button that another slot already uses now swaps the two slots instead of refusing.
- The window closes by itself when combat starts and won't open during combat.
- Checked in the game: while the window is open, button presses go only to the window and don't fire abilities underneath.

## 0.3.0
- The layout now sets the other buttons itself, using the same choices your Ubermoc UI saved: Start opens the game menu, Select opens the world map, left stick click toggles auto-run, L4 (paddle 2) interacts with your target and L5 (paddle 4) jumps.
- These buttons work in every modifier set, so jump and interact still work while R4 or R5 is held.
- `/ubf layout extra` lists them and `/ubf layout extra <button> <command>` changes one. Commands: TOGGLEGAMEMENU, TOGGLEWORLDMAP, TOGGLEAUTORUN, INTERACTTARGET, JUMP, NONE.
- `/ubf layout status` and `/ubf selftest` check these buttons too.
- Note: binds your other addon saved to the game stay in effect after it is turned off. This layout overrides the buttons it uses, so those leftovers no longer matter for them.

## 0.2.2
- New command `/ubf selftest` checks the controller functions, the paddle Shift/Ctrl settings, a few Blizzard button icons and your layout on whatever game build you run it on. It prints the failures and saves every result.
- The debug log is now also saved with your settings, so it survives `/reload`. After a `/reload` the results can be read straight from the saved-variables file without a screenshot.

## 0.2.1
- Fixed: `/ubf layout on` said "Layout applied" even when the game refused the paddle Shift/Ctrl settings. It now reads the settings back and tells you plainly if they were not accepted.

## 0.2.0
- New action bar layout, off until you turn it on with `/ubf layout on`. It uses the game's built-in action bars and only temporary override bindings, so your saved keybinds are never touched. `/ubf layout off` removes it.
- Main bar buttons 1 to 12: X, A, B, Y, d-pad left, down, right, up, R1, R2, L1, L2.
- Hold R4 (paddle 1) to use the same twelve buttons on Action Bar 2, hold R5 (paddle 3) for Action Bar 3, and hold both for Action Bar 4.
- The layout makes the two paddles act as Shift and Ctrl inside the game by setting `GamePadEmulateShift` and `GamePadEmulateCtrl`. It saves your old values and puts them back on `/ubf layout off`. Binding R4 and R5 to Shift and Ctrl in Steam Input still works too.
- Change it with `/ubf layout bind <slot> <button>` and `/ubf layout bar <set> <bar>`. `/ubf layout status` shows what the game really bound, and `/ubf layout reset` goes back to the defaults.
- Changes made during combat wait until combat ends.
- `/ubf padtest` shows one name per axis now. The padmap photo confirmed all three name lookups are 0-based.

## 0.1.2
- New command `/ubf padmap` prints every button, axis and stick name the game defines for your controller, so you don't have to press each button to learn them.
- `/ubf padtest` now shows one name per button instead of two. Your photos confirmed the game's name lookup is 0-based while the state list is 1-based (b1 is the d-pad up, b2 right, b3 down, b4 left).

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
