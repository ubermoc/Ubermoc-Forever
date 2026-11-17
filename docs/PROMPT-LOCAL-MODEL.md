# Prompt for a local model (two tasks, copy everything between the lines)

Give the local model Task 1 first (small, checkable). Task 2 is hard; give it only if Task 1 went well. When it is done, hand the repo back to Claude with `docs/LOCAL-MODEL-REPORT.md`.

----------------------------------------------------------------------

You are working on Ubermoc Forever, a World of Warcraft: Forever addon (Lua) in /home/ubermoc/Downloads/Ubermoc/Ubermoc-Forever. You cannot run the game. You can read and edit code, run the offline test and read the game's log files on this computer.

READ FIRST, IN THIS ORDER
1. AGENTS.md (rules, workflow, how the code is organised).
2. docs/LUA-WOW-GUIDE.md, especially section 3 (taint and secret values) and section 8 (mistakes that already happened).
3. The last four sections of docs/RESEARCH-NAVIGATION.md.
Blizzard's own UI source for this game: ~/Downloads/WoW Forever Tools and Research/blizzard-ui-source-forever/Interface/AddOns (use grep; quote file and line when you rely on it).

THE USER'S RULES
- Only Blizzard's own art, frames and templates. Research the Blizzard source first, do not guess, say what is untested in the game.
- One feature at a time; do not change behaviour the user did not ask about. Short answers.
- Never assume Ubermoc UI is running (the user does not run it with this addon). /run and /dump are blocked in the game.

HOW TO WORK
- First: git checkout -b local-model/secret-audit (Task 1) or local-model/submenu-warning (Task 2). Never commit to main, never release.
- Run the offline test and read the REAL exit code and last line (must say ALL TESTS PASSED):
  ~/Downloads/"WoW Forever Tools and Research"/.venv/bin/python tools/smoke_test.py > /tmp/st.txt 2>&1; echo exit=$?; tail -3 /tmp/st.txt
- Add a case to tools/smoke_test.py for any pure logic you add. Install with: bash tools/install.sh (the user types /reload in the game).
- Bump "## Version" in UbermocForever/UbermocForever.toc (next is 1.3.71) and add a short CHANGELOG.txt entry on top, saying "untested in the game".
- Commit with: git -c user.name=Claude -c user.email=noreply@anthropic.com commit ... and push the branch only.

TASK 1: AUDIT FOR SECRET VALUES
Background: this game gives some answers as SECRET values (for example IsMouseOver or IsIgnoringParentAlpha on a frame our addon may not read). Using a secret value in if / and / or / a comparison / arithmetic raises an error, and pcall does not help because the error is raised on the test, after the call. A real report: "UbermocForever/Fade.lua:398: attempt to perform boolean test on local 'over' (a secret boolean value)", 340 times. It was fixed with a helper that returns nil for a secret (look at `plain` in UbermocForever/Fade.lua and the rule in docs/LUA-WOW-GUIDE.md section 3). The check function is `issecretvalue(v)` (see Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua).
Your job: read every .lua file in UbermocForever/ and find other places where a value that comes from a game API call (frame methods such as IsShown / IsVisible / IsMouseOver / GetAlpha / GetPoint / GetWidth, unit functions, C_* functions, GetCVar ...) is tested, compared or used in arithmetic, where the answer could be secret. Concentrate on code that runs often (OnUpdate handlers, tickers, scans in GameNav.lua, Fade.lua, Cinematic.lua, Aim.lua, Chat.lua, TargetMenu.lua). For each place decide: can it really be secret (only some frames and units are)? If yes, guard it the same way as `plain`. Do not guard values that are our own data. Do not change behaviour otherwise.
Write down every place you looked at and your decision, with file and line.

TASK 2: THE SUBMENU WARNINGS (hard; only if Task 1 went well)
When A is pressed on a menu entry that has a submenu, GameNav.lua (the PostClick hook of the secure A button, search for G.opensSubmenu) runs the entry's OnMouseDown script so the game builds the submenu. That build runs under OUR taint. The game then prints:
  UnitPopupSharedButtonMixins.lua:2585: attempt to compare a secret number value (execution tainted by 'UbermocForever')   (only when the unit already has a target marker; it is UnitPopupRaidTargetBaseMixin:IsChecked comparing GetRaidTargetIndex)
  UnitPopupSharedButtonMixins.lua:27: attempt to index field 'fontString' (a nil value)   (ConfigureButton; also reported when the target is an enemy player, whose menu in the game's source has no marker entry: Blizzard_UnitPopup/Camelot/UnitPopupMenus.lua)
Known: wrapping the call in securecallfunction does not help; running a menu entry's OnEnter from our code taints the menu; storing a frame in the secure button's clickbutton attribute taints the click; a frame reference plus restricted snippet stores a handle and breaks every press. Setting a marker works (a secure button of type raidtarget, G.markerOf). Do not break that.
Ideas: (1) open the submenu without our code running first (secure path, the game's own hover timer in Blizzard_Menu/Menu.lua); (2) avoid only the failing checked-state evaluation; (3) our own context menu for the markers with the game's own MenuUtil.CreateContextMenu, only Blizzard art. If nothing works, say so plainly and why. To find a taint source use the game's taint log, not guesses: ask the user to run /console taintLog 2, /reload, repeat the action, /logout, then read Logs/taint.log (path in docs/LUA-WOW-GUIDE.md section 3).

HAND BACK (required)
Write docs/LOCAL-MODEL-REPORT.md: what you read, what you tried (including failures and why), what you changed (files, functions), the offline test result, what is NOT verified in the game, what you would try next. Tell the user the branch name. Keep it short and honest.

----------------------------------------------------------------------
