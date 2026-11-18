# Local model report: name-only nameplates (1.3.117)

Branch `local-model/nameplates` (from `claude/affectionate-cray-lhlr0j`). Branch only, not pushed to `main`, nothing released.

**Status: passes the offline test and the checker; untested in the game.** Nothing below was seen in the game.

## Files
- `UbermocForever/Nameplates.lua` — new file, `UF.Nameplates`, added to the toc after `Vendor.lua`.
- `UbermocForever/QolPage.lua` — a "Nameplates" group on the Quality of life page: `enemyBtn` ("Enemies: name only"), `friendlyBtn` ("Friendly: name only"), as a new fourth navigation row. `QP.refresh` text, `QP.build`, `QP.navRows`.
- `tools/smoke_test.py` — three new tests (pieces and restore, the CVar, the source text) and the Quality of life page row-count test updated to `4/3/1/3/2` (that is the only existing test changed, as the prompt allowed).
- `docs/RESEARCH-NAVIGATION.md` — new section "Name-only nameplates (1.3.117)".
- `CHANGELOG.txt`, `README.md`, `docs/DESCRIPTION.md`, `HANDOFF.md` — one entry each, saying off by default and untested in the game.

## What it does
Two settings, both Off by default. On: a nameplate shows the name with no health bar. Enemy plates and friendly NPCs get five of the game's pieces put to alpha 0 (`SetAlpha`, a plain C call, no game Lua runs); friendly players also get the game's own CVar `nameplateShowOnlyNameForFriendlyPlayerUnits` switched on, because the game has that mode for players only and its own code does the hiding. Off: every piece we hid gets back the alpha it had *before we hid it*, remembered in our own weak-keyed table — not 1 (`selectionHighlight` is `.25`, so putting back 1 is wrong).

Pieces we hide: `HealthBarsContainer`, `selectionHighlight`, `aggroHighlight`, `LevelFrame`, `PlayerLevelDiffFrame`. Never touched: `name`, `CastBarsContainer`, `WidgetContainer`, `RaidTargetFrame`, `ClassificationFrame`, `AurasFrame`.

No hook, no OnUpdate, no method call on a game piece, no field written on a game frame, no `SetPoint`, no `SetText`/`GetText`, no `Show`/`Hide`, no unit data beyond `UnitCanAttack`. Our state is our own table (`orig`, weak keyed by piece) plus `N.pending` and the settings (`UbermocForeverDB.plates`: `enemy`, `friendly`, `prevOnlyName`).

## Check A — checker
```
$ python3 tools/check_lua.py UbermocForever/Nameplates.lua --risky
UbermocForever/Nameplates.lua: syntax ok (Lua 5.1); 11 globals read, 0 written, 0 unknown
  risky  SetCVar|C_CVar\.SetCVar  lines 151  -> writes a game setting: out of combat, remember the old value, give it back
PASSED
```
The one risky hit is `SetCVar`, which is what we do want: only the one CVar, only out of combat, the player's previous value kept and given back. `QolPage.lua` has the same hits it always had (`SetPoint`, `SetText`, `Show`/`Hide`) — all on our own page frame, our own buttons and the game tooltip, not on a game piece; the new lines add three `SetPoint` (our buttons), two `SetText` (through `QP.refresh` on our buttons) and no `Show`/`Hide`.

## Check B — offline test
```
$ ~/Downloads/"WoW Forever Tools and Research"/.venv/bin/python tools/smoke_test.py
exit=0
...
Nameplates: only the five pieces hidden, each piece gets its own original alpha back, forbidden and missing plates make no call: OK
Nameplates CVar: the player's value is kept and given back, nothing written in combat, nil GetCVar survived: OK
Nameplates: no hook, no OnUpdate, no anchoring, no unit data, no Show/Hide, one SetCVar: OK
ALL TESTS PASSED
```
Fake plates are plain tables whose `SetAlpha` records the value and the number of calls. The tests cover: `parts` skips a piece that is missing or has no `SetAlpha`; Enemies on hides exactly the five and never `name` or `CastBarsContainer`; a plate reused for a friendly unit gives each piece its own original alpha (`1-0.25-0.5-0.75-0.9`, the `.25` proves it is not "back to 1"); a piece we never hid makes no call; a forbidden plate, a plate with no `UnitFrame` and a nil plate make no call; a piece the game refuses keeps its own alpha; a secret `GetAlpha` answer is not remembered so that piece goes back to 1; a secret `UnitCanAttack` answer puts everything back; the option switched off restores the plates already on screen; `NAME_PLATE_UNIT_ADDED` and `UNIT_FACTION` through the frame's `OnEvent` (including a plate whose own unit differs from the unit in the event); `GetNamePlates` answering nil; the CVar: first On stores the player's value and writes 1, Off gives it back, in combat nothing is written and `N.pending` is set and applied on `PLAYER_REGEN_ENABLED`, `GetCVar` answering nil or raising writes nothing.

## Check C — nothing puts an alpha back
```
$ grep -rn "SetAlpha" blizzard-ui-source-forever/Interface/AddOns/Blizzard_NamePlates/      (no hits)
$ grep -n  "SetAlpha" .../Blizzard_UnitFrame/Shared/CompactUnitFrame.lua
1518:	frame:SetAlpha(CompactUnitFrame_GetRangeAlpha(frame));
1884:	frame:SetAlpha(1);
2001:	frame:SetAlpha(1);
$ grep -rn "ignoreParentAlpha" .../Blizzard_NamePlates/
Blizzard_NamePlates/Blizzard_NamePlates.xml:299: <Texture parentKey="selectionHighlight" ... alpha=".25" ignoreParentAlpha="true" ...>
```
1518 is inside `CompactUnitFrame_UpdateCenterStatusIcon`, 1884 `DefaultCompactUnitFrameSetup`, 2001 `DefaultCompactMiniFrameSetup` — all on `frame` itself, and nameplates call none of them (no hits for those names in `Blizzard_NamePlates/`). `aggroHighlight` is driven only by `SetShown` (922) and `SetVertexColor` (926), never by `SetAlpha`. So the alphas we own stay ours; no hook and no OnUpdate needed.

## Check D — the ten questions, with line numbers
1. `plate.UnitFrame` nil → `style` returns at line 100, no call.
2. a piece nil, or without `SetAlpha` → skipped in `parts` (69, 72), never set.
3. `issecretvalue(can)` true → `kindOf` returns nil (61-62) → `wanted` false (52-55) → `style` takes the restore branch, everything put back (107-111).
4. `C_NamePlate.GetNamePlates()` returns nil → `type(plates) ~= "table"` → `applyAll` returns (117), nothing styled.
5. `InCombatLockdown()` true → `N.pending = true` and return (132); applied on `PLAYER_REGEN_ENABLED` (170-173).
6. `uf:IsForbidden()` true → `style` returns (101-104), no call; a forbidden plate is also never returned by `GetNamePlateForUnit` (`includeForbidden` defaults to false), so `styleFor` (124-125) has nothing to style.
7. the same `UnitFrame` reused for another unit → `NAME_PLATE_UNIT_ADDED` calls `style` again, which decides both ways from the plate's own unit token (105); each piece has its own remembered value in `orig` (32).
8. the option switched off while plates are on screen → `toggle` (154-160) calls `applyAll` (114-119) → `restore` for every piece we hid (88-94), each with its own value (110).
9. `GetCVar` answers nil (or raises) → `syncCVar` returns without writing (138-140). Deliberate: if the value cannot be read it cannot be remembered, so the option does not touch the CVar; the alpha hide still applies.
10. our saved settings: `plates.enemy`, `plates.friendly` (boolean), `plates.prevOnlyName` (string or nil). Nothing else. `orig` is a weak-keyed table, not saved.

## Check E — mutation checks
Each mutation was applied to `UbermocForever/Nameplates.lua`, the offline test re-run, and undone. All made a test fail: restore puts back 1 instead of the remembered value; `name` hidden as well; the `pcall` in `hide` removed; the `pcall` around `GetCVar` removed; the combat guard in `syncCVar` removed; the `issecretvalue` answer in `kindOf` removed; the `type(v) ~= "number"` guard removed; the `IsForbidden` check removed; a piece without `SetAlpha` no longer skipped; only the hide branch (no restore on a reused plate); the pending flag not applied at combat end; the original alpha remembered every time instead of the first time only; `NAME_PLATE_UNIT_ADDED`, `UNIT_FACTION` or `PLAYER_REGEN_ENABLED` not registered; the plate styled from the event's unit instead of its own unit; nil plate / nil `UnitFrame` not survived; `prevOnlyName` not remembered; writing when the value cannot be read; `toggle` not re-applying to plates already on screen; `GetNamePlates` answering nil not survived. The file was restored afterwards (`diff` clean).

## Check F — no local used before it is declared
`plain` (35) before `db` (40), `db` before `N.enabled`/`N.wanted`/`syncCVar`/`toggle`, `orig` (32) before `hide`/`restore`, `N.pending` (33) before `syncCVar`, `CVAR` (28) before `syncCVar`, `PIECES` (30) before `parts`, `styleFor` (122) before the `OnEvent` (169). `pcall` return positions: `ok, was` (80, 137), `ok, plates` (116), `ok, plate` (124), `ok, forbidden` (102), `ok, can` (59). `ipairs` runs over `PIECES` and over the list `parts` built, never over a table with holes.

## Check G — the weak table
`orig = setmetatable({}, { __mode = "k" })` (32): keyed by the game's piece. We never write anything on the game frame — `orig[piece]` lives in our table, the piece is only a key. A plate is reused between units, so a piece is the same table for its whole life on screen; the remembered value is the alpha from *before the first hide*, and `restore` clears the entry when it gives the value back (93), so a piece we never hid is never put to 1. A piece that goes away is dropped by the collector, and a fresh entry is taken the first time that piece is hidden again.

## Untested in the game
- Whether `SetAlpha` is accepted on the game's plate pieces for addon code (`SetAlpha` is not restricted in the API documentation, `SimpleFrameAPIDocumentation.lua:1134`); the game can still refuse one piece — `hide` uses `pcall` and a refused piece keeps its own alpha.
- Whether an addon's `SetCVar` makes the game re-apply `UpdateShowOnlyName` to friendly plates already on screen; new plates get it at `OnUnitSet` (`Blizzard_NamePlateUnitFrame.lua:161`) and when isPlayer/isFriend changes.
- Whether the plates are forbidden to addons in an instance (`IsForbidden`, `SimpleFrameAPIDocumentation.lua:242`). If nothing changes there, that is the reason and there is no workaround: say so, do not look for one.
- Whether the aggro flare still shows: `aggroHighlight` is logic-only (`Blizzard_NamePlates.xml:307`) and its three child textures (`310-329`, `aggroHighlightTextures`) are driven by `SetShown`, which we are not allowed to call, so a flare can still appear over an invisible bar. Not worked around.
- The look of the Quality of life page's new row, and the D-pad reaching the two new buttons.

## Game test plan
1. Out of combat, Enemies on: a nameplate shows only the name — bar, level and highlight invisible, cast bar still there, clicking where the bar was still targets.
2. Friendly on: a friendly player's plate shows name only (the game's own mode, with the click area cleared). The Nameplates game setting reflects the value we set; switch the option Off and the game's own checkbox must show the value you had before.
3. A friendly NPC plate with Friendly on, Enemies off: bar invisible, name readable.
4. Target a plate: no bar-shaped glow (the highlight is set to invisible, so it shows nothing while on).
5. Tab through units: a plate reused for another unit must change both ways (a friendly plate reused for an enemy gets hidden again).
6. New plates arriving in combat while Enemies is on get hidden when they appear.
7. Turn an option Off with plates already shown: the bars come back with the alpha each piece had before we hid it (check `selectionHighlight` is not brighter than before).
8. In combat, switch Friendly on: nothing happens until the fight ends, then the CVar is written.
9. An instance: check whether anything changes at all; if not, the plates are likely forbidden to addons — report it, no workaround.
10. Taint log: `/console taintLog 2`, `/reload`, five minutes including a fight, `/logout`, then search `Logs/taint.log` in the Steam compatdata folder for `UbermocForever`. Nothing should appear. If `SetAlpha` on a game piece shows up, stop and report.

## What the user should look at first
The friendly player plate (name only, no bar, no auras, click area cleared by the game), an enemy plate (bar gone, name stays, cast bar still shows, clicking where the bar was still targets), the target highlight (no bar-shaped glow), a plate reused for a different unit, new enemy plates arriving in combat, an instance, and an option switched off bringing the bars back on plates already shown. Possible remaining aggro flare as above.
