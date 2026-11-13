# HANDOFF: Ubermoc Forever (2026-11-13 16:45)

Written by Claude from the session record and the game's own saved data, because the user stopped the local AI's repair attempt (nothing was changed in this folder after commit da92af2; `git status` is clean).

## State
- Phase 1 (spec lines 1-4: first-load popup, Blizzard layout applied through saved bindings) WORKS in the real game (user, 2026-11-13 11:42). Commit dd02cdc. Do not touch `Layout.lua`'s approach.
- Phase 2 (commit da92af2: settings page, bind screen, window navigation) passed 60 of 60 OFFLINE tests but does NOT work in the game. The offline tests ran against a fake of the game's windows, which is why they proved nothing.

## What the user saw in the game (their words, 16:31)
"The d pad does not move through menus or anything at all, the a and b buttons don't do anything, there's no direct options tab in the game menu to go to our mod settings, controller nav in windows does it need to be a toggle option, that should happen automatically, and the Ubermoc Forever [settings page] shows absolutely nothing on that screen ... it didn't implement anything. ... no guess work."

## Verified facts (from the game's saved data and the code)
1. **Real in-game error**: `Nav.lua:177: table index is nil` in `maker` (called from `NavOpen`, Nav.lua:284). The gossip map uses `goodbye:GetName()` as a table key (Nav.lua ~176-177); a nil name makes that error. That `GoodbyeButton` is unnamed in the real game is the likely cause, not yet proven (the probe below proves it).
2. **Saved data shows `navWindows = false`** (WTF SavedVariables/UbermocForever.lua), while `Core.lua:10` defaults it to `true`. `Nav.lua:281` returns immediately when it is false, so window navigation never started. Why it became false is unknown: the user may have unticked the box, or `Settings.RegisterAddOnSetting` (Options.lua:27) wrote it. The user wants NO toggle at all.
3. **No game-menu (Esc) button exists.** Options.lua only registers a category in the Settings window (Esc > Options > AddOns). Spec line 5 asks for BOTH an Esc-menu entry and the Options page. The Esc-menu entry was never built in this phase.
4. **The game menu rebuilds its buttons every time it is shown** (`GameMenuFrameMixin:OnShow` calls `InitButtons`, Blizzard_GameMenu/Shared/GameMenuFrame.lua:61-72), and a button's callback runs after `HideUIPanel(self)` inside Blizzard's own function (:166-171). In the earlier project this produced `ADDON_ACTION_FORBIDDEN ... 'callback()'` (taint): the page must be opened from a deferred call (`C_Timer.After(0, ...)`), and the button re-added after each rebuild.
5. The only other addon errors in the game's error log are two old ones from the previous project (RunBinding, callback). 

## NOT known (do not guess these)
- Why the Ubermoc settings page is empty: no Lua error was logged for it.
- Whether the vendor and gossip windows' controls are named the way Nav.lua assumes (`MerchantFrameTab1/2`, gossip options, `GoodbyeButton`).
- Whether pad button presses reach our frames at all while those windows are open (`OnGamePadButtonDown` path), with Blizzard's gamepad UI off.
- Whether the d-pad is claimed by our override bindings or still bound to the layout from Phase 1 (PADDUP etc. are action bar buttons now), so a navigation claim may fight the layout.

## Decisions by the user
- Navigation in windows is automatic: remove the "Controller navigation in windows" checkbox and the `navWindows` saved value.
- Navigation buttons: d-pad moves, PAD1 (A) acts, PAD2 (B) backs out (confirmed by the user through ask_user_question earlier in the Phase 2 session).
- The "Enable UbermocForever" checkbox is gone for good.
- The options page must look like a Blizzard page and also be reachable from the Esc menu.

## Plan for the next session (data first, then build; no fake world)
1. Do NOT use the offline fake world for frames or navigation. Keep `Spec/` for pure logic only. Offline "60 of 60" is not proof for screens.
2. Add one in-game diagnostic, `/ubermoc probe`, that writes to SavedVariables (like `/ubermoc dumpdefaults` did in Phase 1):
   - the Settings category: registered or not, its id, how many rows it has, and the value of `navWindows`;
   - when the vendor and the gossip window are shown: every child button name (`GetName()`, nil if unnamed), whether our OnShow hook ran (a counter), and the exact error if the map maker fails;
   - whether pad button presses arrive at a frame we own while a window is open, and which action the d-pad keys are bound to at that moment;
   - the buttons currently in `GameMenuFrame` and whether `AddButton` exists.
3. The user opens the vendor, a gossip NPC, the Esc menu and the settings page, presses the d-pad and A/B, types `/reload`, and says "tested". Read the saved data yourself, then build from what the game really returned.
4. Fix, in this order: the settings page contents; the Esc-menu entry (deferred open); automatic navigation without the checkbox; the nil-name error (key the map by the frame, not its name, only after the probe confirms it).
5. Ask the user (ask_user_question) about anything the data does not settle, with options; do not decide it.

## Rules that bit this session (the harness now enforces some of them)
- Offline tests against a fake of the game's frames passed while nothing worked: test logic offline, screens in the game.
- The model spent about 86 of 200 minutes on failed context condensing (fixed: summary cap raised 4096 to 10240) and 385 of 688 shell commands on scratch debug scripts.
- Report must list ASSUMPTIONS; ask the user before guessing; run `check` early, not at the end.

## Files
`Core.lua` (events, slash, defaults), `Options.lua` (settings page), `Nav.lua` (window navigation, 404 lines), `Bind.lua` (bind screen), `Layout.lua` (Blizzard layout, works), `DefaultsDump.lua`, `Selftest.lua`, `Tests.lua`, `Spec/` (offline tests), `REQUIREMENTS.md` (spec; lines 5-14 are Phases 2-4). Installed copy in the game folder is the da92af2 build. Not released.
