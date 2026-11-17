# Prompt for a local model: build our own Target Marker Icon menu

Copy everything between the two dashed lines. When the model is done, give the repo back to Claude with `docs/LOCAL-MODEL-REPORT.md` and the branch name.

----------------------------------------------------------------------

You are working on Ubermoc Forever, a World of Warcraft: Forever addon (Lua) in /home/ubermoc/Downloads/Ubermoc/Ubermoc-Forever. You cannot run the game. You can read and edit code, run the offline test and read the game's log files on this computer.

READ FIRST, IN THIS ORDER
1. AGENTS.md (rules, workflow, how the code is organised).
2. docs/LUA-WOW-GUIDE.md, sections 3 and 8 (taint, secret values, mistakes that already happened).
3. The last five sections of docs/RESEARCH-NAVIGATION.md.
Blizzard's own UI source for this game: ~/Downloads/WoW Forever Tools and Research/blizzard-ui-source-forever/Interface/AddOns (use grep; quote file and line when you rely on it).

THE USER'S RULES
- Only Blizzard's own art, frames and templates (the game's own menu templates, its own marker icons). Nothing drawn by us.
- Research the Blizzard source first, do not guess, say what is untested in the game. One feature at a time. Short answers.
- Never assume Ubermoc UI is running. /run and /dump are blocked in the game.

THE PROBLEM
With a controller, the user opens the target's unit menu (interact key). It has an entry "Target Marker Icon" with a submenu (the markers). Our highlight code (UbermocForever/GameNav.lua) opens that game submenu by running the entry's OnMouseDown script from our PostClick hook (search for G.opensSubmenu). That build runs under OUR taint, so the game prints Lua warnings (UnitPopupSharedButtonMixins.lua:2585 "attempt to compare a secret number value" when the unit already has a marker, and :27 "attempt to index field 'fontString' (a nil value)"). We could not find a way to open the GAME's submenu without our taint (securecallfunction does not help, see the notes).

THE TASK (longer, but step by step): replace the game's marker submenu with our own menu, built with the game's own menu code, so the game's submenu is never built from our code.
Setting a marker already works and must keep working: a secure button of ours of type "raidtarget" (UbermocForeverMarkBtn, G.markerOf in GameNav.lua) sets it when A is pressed on an entry. Do not replace that button.

Steps:
1. Research (write what you find in docs/RESEARCH-NAVIGATION.md under a new heading): how the game builds a context menu: Blizzard_Menu/MenuUtil.lua (MenuUtil.CreateContextMenu, CreateTitle, CreateButton, CreateRadio), Blizzard_Menu/Menu.lua (OpenContextMenu, AddInitializer, CloseMenus), and how the game builds the marker entries: Blizzard_UnitPopupShared/UnitPopupSharedButtonMixins.lua (search UnitPopupRaidTargetBaseMixin: AttachTexture, SetSpriteSheetCell with "Interface\TargetingFrame\UI-RaidTargetingIcons", RAID_TARGET_TEXTURE_ROWS and COLUMNS) and how the target frame places its menu (Blizzard_UnitFrame/Mainline/TargetFrame.lua, TargetFrame_OpenMenu: menu:ClearAllPoints(); menu:SetPoint("LEFT", self, "RIGHT")).
2. New file UbermocForever/MarkerMenu.lua (add it to UbermocForever.toc after GameNav.lua). It exposes UF.MarkerMenu.open(anchorFrame): it closes the game's menus (the game closes other menus when a new one opens), then opens our own context menu with MenuUtil.CreateContextMenu: a title (the unit's name), then nine buttons in this order: the markers 8 down to 1 (names are the game's own global strings _G["RAID_TARGET_"..i]) and then None (RAID_TARGET_NONE). Each button gets the marker's icon on its right with the same texture calls the game uses. Our buttons' own callbacks do nothing: the marker is set by the existing secure button. Do NOT show which marker is current (GetRaidTargetIndex can be a secret value for our code; if you want it, guard with issecretvalue). Place the menu next to the anchor with the same SetPoint call the target frame uses.
3. In GameNav.lua, in the PostClick hook: when the highlighted entry is the game's "Target Marker Icon" entry (its text equals the game's global string RAID_TARGET_ICON; helper entryText(f) exists), call UF.MarkerMenu.open(f) instead of running OnMouseDown, and do nothing else for that press. Other entries with submenus keep the old path.
4. Our menu is the game's open menu, so GameNav should already treat it as a fresh window and put the highlight on its top entry. Make G.markerOf recognise entries of OUR menu (they are inside the frame the menu manager returns as its open menu, see openMenus() in GameNav.lua) by their text, the same way it does for the old submenu. A on an entry then sets the marker through the existing secure button and closes the menus.
5. Tests: add cases to tools/smoke_test.py for the pure logic (which entries map to which marker number). Run the offline test and read the REAL exit code and last line (must say ALL TESTS PASSED):
   ~/Downloads/"WoW Forever Tools and Research"/.venv/bin/python tools/smoke_test.py > /tmp/st.txt 2>&1; echo exit=$?; tail -3 /tmp/st.txt
6. Install with: bash tools/install.sh (the user types /reload in the game). Bump "## Version" in UbermocForever/UbermocForever.toc (next is 1.3.71), add a short CHANGELOG.txt entry on top ("untested in the game"), and add one line to README.md and docs/DESCRIPTION.md only if the visible behaviour changed.

HOW TO WORK
- First: git checkout -b local-model/marker-menu. Never commit to main, never release.
- Commit with: git -c user.name=Claude -c user.email=noreply@anthropic.com commit ... and push the branch only.
- If a step cannot be done the way written (for example the menu API differs from this description), stop and say exactly what you found in the Blizzard source instead of improvising.

HAND BACK (required)
Write docs/LOCAL-MODEL-REPORT.md: what you read, what you did step by step, what you changed (files, functions), the offline test result, what is NOT verified in the game, what you would check first in the game. Tell the user the branch name. Keep it short and honest.

----------------------------------------------------------------------
