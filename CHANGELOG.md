# Changelog

## 0.8.4
- B and Start now do what Esc does. They go through the game's own Esc path (`ToggleGameMenu`), which closes pop-up dialogs, the settings panel, menus, windows and bags in the right order, and in the same order on Midnight and Forever (both builds' code checked). Before, they only closed windows, so a pop-up dialog or the settings panel could not be backed out of. If nothing claims the press and Esc would open the game menu, the menu is put away again.
- The first D-pad press in a menu goes to the nearest button when the cursor is not on one yet (a freshly opened game menu, a pop-up), instead of doing nothing. After that the D-pad moves from button to button as before. The game only allows the cursor to be placed in answer to a controller press, so it cannot jump there by itself when a menu opens.
- Checked against the game's code on both builds: the game menu is a normal window panel, so the cursor, A (click) and B (back) work in it, and A on the new Ubermoc Forever button opens the options.

## 0.8.3
- The game menu (Esc, or Start with the controller) now has an "Ubermoc Forever" button at the very top, in the menu's own button style, that opens the options window. It is added each time the menu opens, so it stays in place when the menu rebuilds, and the game's own buttons keep their order below it with a gap between. On Forever it is also put first in the menu's controller navigation list.

## 0.8.2
- New `/ubf test`: one command that runs the self test, saves a snapshot (controller, labels, cursor state, the game settings that matter, other loaded addons and the recent log), then records every button you press for 30 seconds. For each press it notes whether the addon took it, whether it fired an ability instead, or whether nothing happened, and how far the cursor moved. Open a bag, press the D-pad, A, X and B, then `/reload` and the full report is saved in the addon's saved variables. `/ubf test stop` ends it early, and it stops by itself when combat starts.

## 0.8.1
- Fixed: pressing the D-pad quickly fired abilities instead of moving the cursor. The game switches its cursor off and on again by itself, and each time the buttons were let go until the next check. They now stay taken for as long as a window is open, and the cursor is re-enabled within a tenth of a second.
- Button labels: changing the row now tells you exactly what happened (how many controller configs were changed, already right, missing or refused by the game) and which style the active controller reports afterwards, so a change that has no effect can be told apart from one that is refused. Every attempt is written to the log, the action bars redraw their button text right after a change, and in Auto the all-devices setting follows too while a Steam pad is connected, because the combined controller takes its style from there.

## 0.8.0
- The D-pad now moves the game's cursor from button to button while a window is open and the cursor is on. It jumps to the nearest button in the direction you press, so bag slots, vendor items, tabs and close buttons are all reachable without the stick. The right stick still moves the cursor freely.
- A and X now send real mouse clicks (left and right) at the cursor, so they work on anything the cursor points at, not only plain buttons. If the game refuses a simulated click, it falls back to clicking the button under the cursor.
- L2 and R2 scroll the list under the cursor up and down.
- The game does not document the units its cursor-placing function takes, so the first move is checked against where the cursor really lands and corrected. The result is written to the log ("cursor units").
- Item menus (options on a bag item, spell-to-bar binding and so on) are the next step.

## 0.7.0
- Controller buttons on the action bars and in menus can now show A, B, X and Y, using Blizzard's own button art. The game draws buttons from a "label style" it keeps for each controller (Generic numbers, Letters, Shapes or Reverse). Steam Input shows the game an Xbox-style pad labelled Generic, so by default this switches Valve's pad to Letters.
- The Other page of the options window has a "Button labels" row: Auto (Letters for Steam), Game default (changes nothing), Numbers, A B X Y, Shapes or Reverse. `/ubf labels` does the same with a status line that shows what each controller is set to.
- It uses the game's own controller settings, so it works the same on Midnight and Forever. Open a window or `/reload` to see the new labels.
- `/ubf selftest` now checks the glyph art Blizzard's own labels use and records each controller's label style.

## 0.6.0
- The game's own gamepad cursor now works with this layout. When any window opens (bags from the backpack key, map, game menu, vendors and so on) the cursor turns on so the right stick moves it, and it goes away when the windows close. A cursor you start yourself is left alone.
- While the cursor is on and a window is open, A clicks what the cursor points at, X right-clicks it, and B or Start closes windows (and with none open, gives the stick back). These buttons no longer fire abilities underneath. Y is held back for now.
- When combat starts, every window closes, the cursor turns off and the buttons are your abilities again. This includes the options window and can be switched off.
- On Forever, where the game has its own gamepad menus, these cursor features start switched off so they never fight them. You can turn them on.
- New commands `/ubf cursor` (status, on, off, auto on|off, actions on|off) and `/ubf binds` (status, clear, restore).
- Another controller addon leaves its binds saved in the game's key bindings even after you turn it off, so they keep firing under this layout. `/ubf binds clear` backs them up and clears them, and `/ubf binds restore` puts them back. The options window has the same two rows on the Other page, and clearing needs a second press of A to confirm.
- The Cursor page has new rows for opening the cursor with windows, A/X/B working the cursor, and closing windows in combat. A star marks a click button that is also used by the layout.
- `/ubf selftest` now also shows whether Forever's own gamepad interface is running and two more cursor settings.

## 0.5.0
- New Cursor page in the options window, for the game's own gamepad cursor (the right stick moves it, and it turns on when you open bags, loot, the map or the game menu). It sets which button left-clicks and which right-clicks (the game's defaults are R2 and R1), turns cursor centering on or off, switches the cursor on or off right now, and resets all of this to the game's defaults.
- L1 and R1 now cycle through four pages.
- The self test now records whether the cursor is on at the moment you run it.

## 0.4.4
- `/ubf selftest` now also reads the game's own gamepad cursor: whether its on/off functions exist, whether it is on right now, and the current values of its click-button and centering settings. This is for planning how the layout should share R1 and R2 with the cursor's clicks.

## 0.4.3
- The window background setting is now called "Window background tint" and still sets how dark the marble behind the rows is, 0 to 100.
- New "Window background opacity" row right below it. It fades the whole window background from 0, completely see-through, to 100, fully showing. The text and border stay readable. It starts at 100.
- Both rows change by 5 with left and right and by 1 with L2 and R2. Your earlier setting is kept as the tint.

## 0.4.2
- The options window background is now an opacity setting from 0 to 100 percent, so you can pick anything between the old Medium and Dark. It starts at 45, the Medium you liked. Left and right change it by 5, and L2 and R2 by 1.
- Your earlier Dark, Medium or Light choice is carried over (100, 45 or 0).

## 0.4.1
- The options window's dark marble background was too dark. It now defaults to a lighter setting, and the Other page has a new "Window background" row to switch between Dark, Medium and Light.

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
