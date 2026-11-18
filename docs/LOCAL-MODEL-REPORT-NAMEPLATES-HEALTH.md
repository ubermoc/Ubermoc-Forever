# NameHealth (1.3.118) report — branch `local-model/nameplates-health`. H (wording rule): every line below is "passes the offline test and the checker"; nothing here is said to work in the game.

| A + B | result |
|---|---|
| A NameHealth.lua | `PASSED`, 13 globals read / 0 written / 0 unknown; risky `:Show()/Hide()` 204, 205, 207, 208, 215, 217, 224, 259, 260, 261 — all our own objects; unit calls sit inside `pcall(UnitName, unit)` (181), `pcall(UnitClass, unit)` (78), `pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)` (241), so the checker's `Unit\w*\(` pattern never matches |
| A Nameplates.lua | `PASSED`, 11/0/0; risky `SetCVar` 160 (friendly name-only cvar, old value kept, phase 1) |
| A QolPage.lua | `PASSED`, 2/0/0; risky `SetPoint/ClearAllPoints` 40, 41, 55, 60, 61, 68, 69, 70, 80, 86, 87, 88, `Show/Hide` 42, 49, 51, `SetFont/SetText` 15, 22-33 — our own buttons and tooltips |
| B | `~/Downloads/"WoW Forever Tools and Research"/.venv/bin/python tools/smoke_test.py > /tmp/st.txt 2>&1; echo exit=$?; tail -3 /tmp/st.txt` → `exit=0`, `ALL TESTS PASSED` |
| C call → doc → line | `CreateFrame`/`CreateFontString` (SimpleFrameAPIDocumentation.lua 78) at 106-109, 112-114; `SetClipsChildren` (1218) 115; `SetFrameLevel`/`GetFrameLevel` (1281/421) 116; `SetStatusBarTexture`/`GetStatusBarTexture`/`SetMinMaxValues`/`SetValue` (SimpleStatusBar 318/136/229/355) 117, 118, 196, 200, 243; `SetVertexColor` (SimpleRegion 191) 120; `SetText`/`SetFormattedText` (SimpleFontString 664/539) 186, 190, 211, 247; `SetTextColor` (SimpleFont 298) 177-179; `GetFont`/`GetJustifyH` (SimpleFont 33/104) 156, 96; `RegisterUnitEvent`/`UnregisterAllEvents` (SimpleFrame 1064/1588) 222-223, 221, 262; `issecretvalue` (FrameScript 287) 50 |

| D — every use of a secret result | line |
|---|---|
| `pcall(UnitName, unit)` | 181: `nm` unchanged into `pcall(o.ours.SetText, o.ours, nm)` (186) and `pcall(o.copy.SetText, o.copy, nm)` (190); never compared, joined, stored or `type`-tested |
| `pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)` | 200, 211, 241: `v` only reaches `SetValue` (200, 243) or `SetFormattedText("%.0f%%", v)` (211, 247) |
| `pcall(UnitClass, unit)`, `UnitReaction`, `UnitIsTapDenied`, `UnitIsPlayer` | 78, 57, 72, 76: `plain()` then a test on the plain answer; `RAID_CLASS_COLORS[token]` only for a plain string token (80-81); a secret gives white |

| E — ten answers | line |
|---|---|
| plate reused for another unit | 220-223: old unit's events dropped before the new ones; the handler compares `payload` with `o.unit` (124) |
| health percent nil, or the call errors | 200-203, 211-214, 242-244: the pcall result is the gate → `NH.clear` and `return false` |
| `CurveConstants.ScaleTo100` is nil | 144, 240: guarded before anything is touched |
| forbidden plate, or no `UnitFrame` | 105 (`plain(forbidden)` return), 195 (`type(plate.UnitFrame) == "table"`), 133, 146 |
| in combat | 232: nothing protected here — our own objects plus phase 1's `SetAlpha` on the game's name |
| game's name hidden, then our text fails | 226-232 last; a failure clears ours and gives the alpha back (259-265) |
| option switched off with plates on screen | `NH.toggle` (40) → `UF.Nameplates.applyAll()` (123) → `NH.clear` (116, 119) |
| player with a secret class token | 79-84: reaction colour, not class colour |
| what is saved | 32-33: `plates.health`, `plates.percent`, plain booleans, default `true`, never overwritten |
| both settings off | 136-138: `show` clears and returns false, the game's name stays visible |

| F — mutation checks (copy in /tmp/mut, run, undone) | result |
|---|---|
| name compared or `plain()`ed before `SetText` | fails: `m1` identity assertion, `false` instead of `true` |
| game's name hidden before ours exists | fails: order `name+fs1+fs2+name` instead of `fs1+fs2+name` |
| `RegisterUnitEvent` without the unit (global event) | fails: `events=nil,target,1`; also trips the source test |
| `pcall` dropped around a secret call | fails: the refused case raises out of the test (`NameHealth.lua:186`) |
| clip TOPLEFT anchored on the texture's BOTTOMRIGHT | fails: the anchors assertion |
| `NH.clear` forgotten in `N.styleFor`'s not-wanted branch | fails: `offs=false,false,0` instead of `offs=false,false,0.8` |

| G — old mistakes checked | result |
|---|---|
| local used above its declaration | none: `plain` 49 before first use 57; `o.name` set 145, used 265 |
| `ipairs` over holes | no table loop in NameHealth; parts come from `N.parts` (Nameplates, unchanged) |
| `pcall` result positions, global typos | 57, 72, 76, 78, 96, 156, 241; 0 unknown globals in all three files |
| not verified in the game | the look itself, and whether the white copy lands on the same letters (the game can scale the font per plate). First things to look at: an enemy hit — colour left, white from the right, no white at full health; the percent descending; a friendly NPC and a friendly player; overlay alignment (ghost, doubled or shifted letters mean wrong anchors or font); a long name; a plate reused for another unit; plates arriving in combat; an instance where plates may be forbidden to addons; each new button off; then `/console taintLog 2`, `/reload`, five minutes with a fight, `/logout`, and search `Logs/taint.log` for UbermocForever |
