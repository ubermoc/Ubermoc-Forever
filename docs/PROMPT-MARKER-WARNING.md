# Task for a local model: the warning when the target-marker submenu is opened again

Copy everything below the line into the local model. When it is done, give the repo back to Claude with the report file it writes (see "Hand back").

---

You are working on **Ubermoc Forever**, a World of Warcraft: Forever addon (Lua) in the folder `/home/ubermoc/Downloads/Ubermoc/Ubermoc-Forever`. You cannot run the game. You can edit code, run the offline test and read the game's log files on this computer.

## Read first, in this order
1. `AGENTS.md` (project rules, workflow, how the code is organised).
2. `docs/LUA-WOW-GUIDE.md`, especially section 3 (taint) and section 8 (mistakes that already happened).
3. The last two sections of `docs/RESEARCH-NAVIGATION.md` ("1.3.67" and "Known warning after 1.3.67").
Blizzard's own UI source for this game is in `~/Downloads/WoW Forever Tools and Research/blizzard-ui-source-forever/Interface/AddOns` (search it with grep; quote file and line when you rely on it).

## The user's rules (do not break them)
- Only Blizzard's own art, frames and templates. Nothing drawn by us.
- Research the Blizzard source first. Do not guess. Say what is untested in the game.
- One feature at a time. Do not change behaviour the user did not ask about. Short answers.
- Never assume Ubermoc UI is running; the user does not run it together with this addon.
- `/run` and `/dump` are blocked in the game: never ask the user to type scripts.

## What works now (confirmed in the game, do not break it)
Pressing the interact key on an enemy opens the target's unit menu (`UbermocForever/TargetMenu.lua`). The highlight (`UbermocForever/GameNav.lua`) moves in the menu with the D-pad. A on "Target Marker Icon" opens its submenu, A on a marker entry sets the marker through a secure button of ours of type `raidtarget` (`G.markerOf`, `UbermocForeverMarkBtn` in `GameNav.lua`), and the menus close. Setting markers works.

## The problem to solve
When the unit **already has a marker** and the user opens the "Target Marker Icon" submenu again (to change the marker), the game prints these two Lua warnings (5 times each):

```
LUA_WARNING: ...UnitPopupSharedButtonMixins.lua:2585: attempt to compare a secret number value (execution tainted by 'UbermocForever')
...Menu.lua:2496 (OnMouseDown) -> CheckForSubmenu -> GenerateSubmenu ... [C]: in function 'pcall'

LUA_WARNING: ...UnitPopupSharedButtonMixins.lua:27: attempt to index field 'fontString' (a nil value)
... same stack ... [UbermocForever/GameNav.lua]:448 in function <GameNav.lua:432>
```

Line 2585 is `UnitPopupRaidTargetBaseMixin:IsChecked`: `(GetRaidTargetIndex(contextData.unit) or 0) == self:GetRaidTargetIndex()`. `GetRaidTargetIndex` returns a *secret* number to tainted code, so the comparison fails, but only when a marker exists (otherwise it returns nil). The second warning is a later entry initializer failing.

## What is already known
- The submenu is opened from our code: `GameNav.lua`, the `PostClick` hook of the secure A button (search for `G.opensSubmenu`), which runs the menu entry's `OnMouseDown` script (`Menu.lua`: `frame:SetScript("OnMouseDown", menu.onElementMouseDown)` -> `CheckForSubmenu` -> `GenerateSubmenu`). A normal click does not open a submenu in this game; only mouse-down or hovering does.
- That build therefore runs tainted by our addon. Wrapping the call in `securecallfunction` does **not** help (tried, 1.3.63). Running the menu's `OnEnter` from our code taints the menu too (it was removed in 1.3.64).
- A frame stored by our code with `SetAttribute("clickbutton", frame)` taints the secure click that reads it. A restricted-snippet frame reference stores a *handle* and breaks every press (1.3.65, removed). Do not retry these.
- The game's own secure action types are in `Blizzard_FrameXML/SecureTemplates.lua` (`SECURE_ACTIONS`).

## Ideas to try (pick the most promising, research before coding)
1. Open the submenu from a secure path: find out whether a secure button, a macro, a click binding or the game's own hover timer in `Menu.lua` (`EnterFrame`, `mouseEventTimerCallback`) can start `CheckForSubmenu` without our code running first.
2. Avoid the failing check: the problem is only the *checked state* of the radio entries (`IsChecked`). See whether the submenu can be built while the unit shows as unmarked, or whether the check can be skipped, without writing to Blizzard tables or frames (see the guide's rules).
3. Our own context menu for the markers, built with the game's own `MenuUtil.CreateContextMenu` and radio templates, whose entries are pressed through the existing `raidtarget` secure button. Only if 1 and 2 are not possible, and only with Blizzard's own marker icons (`Interface\TargetingFrame\UI-RaidTargetingIcons`).
If none works, say so plainly and explain why; a wrong fix costs the user a game test.

## How to work
- Create a branch first: `git checkout -b local-model/marker-warning`. Do **not** commit to `main` and do **not** release.
- Change the code. Add or update a case in `tools/smoke_test.py` for any pure logic you add. Run the offline test and read the real exit code and the last line; it must say `ALL TESTS PASSED`:
  `~/Downloads/"WoW Forever Tools and Research"/.venv/bin/python tools/smoke_test.py > /tmp/st.txt 2>&1; echo exit=$?; tail -3 /tmp/st.txt`
- Install into the game with `bash tools/install.sh` (the user types `/reload` in the game).
- Bump `## Version` in `UbermocForever/UbermocForever.toc` (next is 1.3.68) and add a short `CHANGELOG.txt` entry on top. Say "untested in the game" in it.
- To find a taint source, use the game's taint log, not guesses: the user runs `/console taintLog 2`, `/reload`, repeats the action, then `/logout`; read `Logs/taint.log` (path in `docs/LUA-WOW-GUIDE.md` section 3). Ask the user for exactly this when you need evidence.
- Commit on your branch with `git -c user.name=Claude -c user.email=noreply@anthropic.com commit ...` and push the branch only.

## Hand back (required)
Write `docs/LOCAL-MODEL-REPORT.md` with: what you read, what you tried (including what failed and why), what you changed (files and functions), the offline test result, what is **not** verified in the game, and what you would try next. Tell the user the branch name. Keep it short and honest.
