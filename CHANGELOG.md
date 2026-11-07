# Changelog

## 1.0.2
- Context-aware transitions. While a game frame is open (spellbook, bags, professions, the game menu or an NPC dialog) your plain paddle presses reach your utility/secondary bar first, and the paddles snap back to your normal bars the moment the frame closes. Combat always wins: entering or leaving combat is applied instantly and can never be queued behind a menu swap.
- Rapid open/close of windows is safe — the switch settles after 200 ms of the window staying open, and each swap is one atomic rebind, so your bars can never get stuck half-changed.
- Binding hint overlays now fade in over a tenth of a second using the game's own animation system, instead of popping in.
- New command `/ubf transitions [on|off|status]` to toggle the behaviour or see which bar set is live right now.
- Self test now reports that the transitions module started and is enabled, and it understands the new bar behaviour: with a window open (spellbook, bags, NPC dialog…) your paddles are on the utility bar by design, so the bar-binding check no longer reports that as a failure.

## 1.0.1
- Rogue default layout (checkpoint 5). The class layout is now a Lua data file, `Layouts/Rogue/default.lua` (the old `Layouts/Rouge/` JSON is gone — the game cannot read JSON anyway). It lists the abilities for all three specs in a three-bar set: primary, secondary and tertiary bars, with "show only the active bar" on by default.
- Every spell ID in that layout is taken from the game's own data on this build (the abilities each spec tracks), and the addon checks each one against your character at login and keeps only the spells you actually have, so a wrong ID can never reach a bar. The spec is matched by its name (Assassination / Outlaw / Subtlety): this build reports new-range spec IDs from the API (an Outlaw reads 1488 in-game), so matching the old 259/260/261 table numbers would pick the wrong spec's list.
- The layout now actually loads. Before this build the load step was broken and silently skipped, so the class layout never took effect. You will see a "layout loaded for Rogue: … known spells" line in the log after login.
- The action bar buttons now show your pad buttons. The binding registration is in the gamepad binding context (the same way the game's own pad bindings are set), and the pad name is written into the button's own hotkey box — the engine always reports the keyboard key ("1") as the action's primary binding, so the game's native glyph display never picks the pad key; writing the label the same way Ubermoc UI labels its slots is the reliable path. Taken away again with `/ubf layout off`.
- Your spec is now detected reliably. It is resolved from the game's own specialization API and matched to the layout by spec name, and the self test reports which spec and how many spells matched — and now prints the spec and the resolved spell names to chat when it runs, so you do not have to dig through files to see it.
- New command `/ubf layout spells`: prints the layout's ability list for your active spec, with the names the game resolves them to, so you can place them on your action bars.
- The binding hints are back. They were never being started, which is why they did not show. They now start on login: spellbook, NPC dialogs, bags and the game menu each show the button that does the job, in the game's own binding text. Bag hints now use the bag frames this build actually has.
- Self test passes clean: removed six probe names (five gamepad glyph atlas names and the `GamePadEmulateEsc` cvar) that do not exist in this build. The legend checks each glyph at runtime and falls back to the letter art, so nothing is lost. The action-bar glyph line is reported as information (the engine shows the keyboard key until the pad is engaged, then the pad key); the actual pad-binding registration is still asserted as a hard check.

## 1.0.0
- Dropped all support for World of Warcraft: Midnight (TOC 120105). The addon now ships only on TOC 16001 (Forever). Removed `isForever`/gameType dual-path logic from Compat.lua (`gameType` is always "Forever", no more `toc == 120105` checks). Legend picture style picker reduced to Auto / Letters / Forever with Auto defaulting to Forever. Options window template name changed from "Midnight" to "Plain". CLAUDE.md rules updated: API verification only against the `forever` branch of Gethe/wow-ui-source; installation only into `_forever_` folder (no more dual-game-path). tools/check.py no longer enforces 120105 in TOC. CHANGELOG history entries documenting past releases are preserved as-is; no Midnight references remain in live code or player-facing strings.

## 0.10.1
- New `/ubf reload` command. Put it in a one-line macro on an action bar slot your controller reaches (for example Action Bar 4, held with both paddles) and you can reload the UI with one button.
- New auto test, for testing the addon: `/ubf autotest on` (or "Self test on every load" on the Other page of the options) runs the self test by itself every time the UI loads and saves the results, so they can be read from the saved variables after a /reload. It records the addon and game version, what started it (login or reload), every check with pass or fail, any Lua errors from this addon, and which checks newly failed or were fixed since the last run. It is off by default. `/ubf autotest now` runs it on demand and `/ubf autotest` shows the last result.
- If the self test itself hits an error, that is now recorded as a failed check instead of stopping the test.
- For development: a watcher script prints a pass/fail summary each time the game saves the results, and the offline checks now also load the addon as Midnight.

## 0.10.0
- Drop-down lists in the options. Press A on any row that has a set of choices and a list opens next to it, in the game's tooltip panel look: the D-pad moves, A picks, B closes it without changing anything. The current choice is shown in gold. It works for the Shift and Ctrl paddles, the bar each paddle set reaches, the other-button commands (Start, Select, L3, L4, L5), the cursor click buttons, the button labels and the interface style. The legend at the bottom changes to Move / Choose / Cancel while a list is open, and the list opens below the row, or above it near the bottom of the window. The old left / right stepping still works on those rows.

## 0.9.9
- The legend is now part of the window it describes instead of a floating bar. It is attached along the window's bottom edge (below its tabs, or above the window if there is no room), as wide as the window, drawn in the game's own tooltip panel style, and it moves, scales and hides with the window. Its text is always the same size; when a window is narrow the entries wrap onto a second line instead of shrinking, so nothing changes size from tab to tab. A picture and its label never split across lines.
- This replaces the 0.9.7 and 0.9.8 behaviour of shrinking the legend to fit.

## 0.9.8
- The legend is now one size everywhere. In 0.9.7 it was shrunk to each window's own width, so it was smaller on Reputation and Currency than on Character. It is now sized once to fit Blizzard's standard panel width (338), so it is the same on every tab and window, and fits inside any panel that wide or wider. Only a window narrower than that makes it smaller. The pictures and spacing are slightly tighter so it stays easy to read at that size.

## 0.9.7
- The legend no longer jumps around when you switch tabs. It used to centre itself on the window, and a window like Character changes width from tab to tab, so it moved. It now lines up with the window's left edge, which does not move, and sits under the lowest tab.
- The legend now fits inside the window it belongs to. If the window is narrower than the legend (Reputation and Currency on the Character window, for one), the legend shrinks to fit, down to a floor of 60% of its size.

## 0.9.6
- Fixed L1 / R1 jumping to the first or last tab and then only moving between two. The game disables the tab you are on, and the tab finder was leaving disabled tabs out, so it lost track of which tab was current. R1 then always chose the first tab and L1 the last. The current tab now counts as the starting point, so each press goes to the next or previous tab, wrapping at the ends. A window with only two tabs (Dungeons & Raids, Achievements) now also shows "Tabs" in the legend, which it did not before.
- Because those windows' tabs are now found, the legend also sits below them instead of on top of them.

## 0.9.5
- The options window can now be drawn on Blizzard's own portrait panel, the same panel Forever's own screens are built on. It shows Forever's bronze frame on Forever and the plain gray one on Midnight, with the player's portrait and the game's own title bar. The window and the legend share one setting, "Interface style" on the Other page: Auto uses each game's own look (the portrait panel on Forever, the plain panel on Midnight, as before), and Midnight or Forever can be chosen to switch. Changing it redraws the open window at once, on the same page.
- The window background tint and opacity work on both panels; on the portrait panel the tint darkens its rock background.
- If the portrait panel cannot be created for any reason, the plain panel is used and the reason is logged.

## 0.9.4
- Fixed the "interface action failed" error when switching tabs (it showed on the Adventure Guide). The tab was clicked from addon code, which runs the tab's own handler as addon code, and handlers that use protected functions are blocked. L1 / R1 now move the cursor onto the next or previous tab, and a real click is sent when you let go of the button. The game only lets addon code place the cursor or click once per controller event, and the click needs the cursor to have landed, which is why the click happens on release.
- Fixed R1 acting like a mouse click and not switching tabs. The game's own cursor maps R2 to left click and R1 to right click by default, so R1 right-clicked and R2 clicked while scrolling. While this addon has the buttons, those two settings are switched to NONE and put back if the addon stops; a button you chose yourself is left alone. The Cursor page can set them to NONE too.
- The legend no longer covers the tabs that hang below a window. It sits below the lowest tab (or above the window when there is no room), centred on the window.

## 0.9.3
- The legend no longer sits over the main action bar. It now goes under the open window, like the footers on Blizzard's own screens, or above the window when there is no room below, and is kept on screen. It moves with the window.
- The D-pad is one picture with "Move" instead of four. Midnight has no picture for the whole D-pad, so one direction stands for it; Forever uses its own whole-D-pad picture. The self test now also looks for a whole-D-pad picture in Midnight.

## 0.9.2
- Removed the step that told the action bar buttons to redraw their key text after a label change. The game's log showed over a hundred blocked actions on the action bars (MultiBar buttons and containers, the stance bar) in the same minute, and this call into Blizzard's own button code is the only place this addon touched them. The game redraws the key text itself when the controller settings change.
- The legend now catches and logs any error it hits instead of failing silently, and `/ubf legend` prints whether the legend exists, is shown, its style, its width and its text, so a missing legend can be traced.

## 0.9.1
- Fixed an "interface action failed" error when B closed the game's settings panel. Closing it the normal way makes the game step back to the menu, and that step runs its whole Esc action (including stopping a cast, which an addon may not do) from this addon's call, so the game blocked it. B now closes the settings panel without the step back.

## 0.9.0
- Button legend. While a window is open and the controller has the buttons, a legend along the bottom of the screen shows what each button does, in the game's own gold text with the game's own button pictures: D-pad move, A select, X use (right-click), L2 / R2 scroll, L1 / R1 tabs (only when the window has tabs), B back. The options window shows the same kind of legend instead of its old text line.
- L1 / R1 now switch tabs in any open window that has them, as the shoulder buttons do on Blizzard's own controller screens. Both kinds of tab the game uses are handled (checked in the code of both builds), disabled tabs are skipped, and it wraps round at the ends.
- Picture style. The legend defaults to each game's own style: the lettered button art on Midnight, and Forever's own art on Forever. The Other page has a "Button picture style" row (Auto, Midnight, Forever) to switch. Forever's art is not in Midnight, so choosing it there shows the Midnight pictures and says so. Forever's pictures are used on Forever as soon as the game has them.
- The self test now also checks the pictures both styles use.
- Kept as they were: the D-pad moves, L2 / R2 scroll, A / X click, B goes back.

## 0.8.7
- Start in combat no longer tries to show, hide or close any panel, which the game blocks and reports as "interface action failed because of an AddOn". In combat the press only runs the secure macro (stop the cast, clear the target); everything out of combat works as in 0.8.6.
- If the game ever blocks something this addon tried, the event and the action name are now written to the log (`/ubf log`, and the saved variables), so the cause can be found.

## 0.8.6
- Start works in steps again, like Esc on a keyboard, but reliably on a controller. The first press closes pop-ups, the settings panel, menus, windows and bags, clears your target and stops a cast. Once there is nothing left to clear, the next press opens the game menu, and the one after puts it away. Before 0.8.5 it was the game's own Esc action, which on a controller can use up every press; 0.8.5 always opened the menu and never cleared anything.
- Clearing the target and stopping a cast are protected actions, so they run from a secure macro (`/stopcasting`, `/cleartarget`, both checked on Midnight and Forever) on a button that Start clicks. The closing and the menu are done just before it. In combat the press always runs the macro, because a secure button cannot be changed there.
- The Other buttons page shows the new choice as "Clear, close, then menu". The earlier "Game menu (direct)" setting is the same entry, and the game's own Esc action is still there as TOGGLEGAMEMENU.

## 0.8.5
- Start now opens the game menu directly, every time. Before, it ran the game's whole Esc action, which stops casting, clears your target and closes windows first, and the controller's first Esc steps can use up the press, so with a target selected the menu never opened. Start now does what the game's own menu button does: closes the settings panel, menus and windows, then shows the menu (with the Ubermoc Forever button at the top), and pressing it again puts the menu away. It never clears your target. It works with a paddle held too, and in combat. The old behaviour is still available as "TOGGLEGAMEMENU" in the Other buttons page.
- Existing settings are moved over once: if Start was still on the old default, it becomes "Game menu (direct)".
- B closes the top thing with the same safe steps instead of the full Esc action: a dialog first, then the settings panel, menus, windows and bags. This replaces the 0.8.4 behaviour, which could clear your target or stop a cast instead of closing the window.
- New "Reload UI" row under "Run self test" on the Other page. It reloads the interface, which also saves the self test results to disk.

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
