# HANDOFF — UbermocForever (last update: commit 3c40130 on main, 2026-11-13)

Read this FIRST, then REQUIREMENTS.md (Spec lines + Design decisions), then start.

## Where we are
Phase 1 (Spec lines R-1.1..R-1.8) is CODE-COMPLETE and passes `check` (CHECK OK, 40/40 offline tests).
NOTHING is proven in game yet — every spec line for Phase 1 is "offline PASS (fake game only)".
Lines R-1.9..R-1.14 (window navigation, mouse emulation option, quest dialogs) are NOT started: NO TEST.

## Done (commit 3c40130, pushed to github.com:ubermoc/Ubermoc-Forever.git main)
- 20-key default layout (Layout.lua ns.DefaultLayout): every PAD key the user listed — d-pad, face,
  shoulders, triggers, stick clicks, Start/Select, back paddles — bound to Blizzard's always-on
  NORMAL-context actions. The 4 dead GAMEPAD*MOD entries were replaced (user approved 2026-11-13).
- Bind.lua: press-to-bind screen (/ubermoc bind) + conflict/clear/reset/combat rules.
  db.binds[row]=key is the single source of truth ("" = cleared on purpose);
  claimedKey/RebuildClaims (Bind.lua ~:35/:46) derive everything; ApplyLayout clears our claimFrame
  with ClearOverrideBindings and re-claims every login — no ghost claims.
- Spec/R-1.5..R-1.8 test files; REQUIREMENTS.md Design decisions updated.

## WHAT THE USER MUST TEST IN GAME (the next session starts here)
Blizzard's gamepad UI stays OFF (that is the whole point).
1. /reload, accept popup, press each button -> its action fires. Back paddles (PADPADDLE1-4 =
   Steam Deck L4/L5/R4/R5) are UNVERIFIED: if they do nothing, that pad may not report them —
   record the result either way into REQUIREMENTS.md Design decisions.
2. /ubermoc bind -> pick row, press button -> chat "KEY -> ROW bound", new key works, old goes quiet.
3. Clear one row -> only it goes quiet. Reset -> defaults back. In combat -> refuses, changes nothing.
4. /ubermoc selftest then /reload -> records in-game evidence (check reads it). Empty result = the
   selftest did not run, not that bindings broke.

## Known problems / open facts
- Chord rows (SHIFT-/CTRL-) exist but are NOT claimed by default: chord firing on PAD keys unproven.
  If the user's press test shows chords fire, claim them and update R-1.3 (it currently forbids "-" in
  default claims).
- Bind screen look = plain Buttons + ButtonFrameTemplate chrome; Blizzard binding-row template was NOT
  FOUND in Forever source — visual check is the user's.
- The git repo root is UbermocForever/ (the addon folder), NOT the parent.

## How to work (harness rules that bit us)
- First call: recall project=UbermocForever; run specs with
  luajit /home/ubermoc/Downloads/ubermoc-harness-v2/wow/behavior.lua UbermocForever.toc Spec
- Never sed the "local addonName, ns = ..." header (known-mistakes.json entry sed-addon-header).
- A SET binding is not a FIRE: only NORMAL-context actions work with the gamepad UI off. Never ship
  GamepadModeInGameCore actions. R-1.3 test enforces this.
- Overrides live on our own claimFrame, never UIParent; ClearOverrideBindings is /nocombat restricted —
  every path that clears must check InCombatLockdown() first.
- ConsolePort was studied as reference only; never name it in code/comments/docs.

## Next steps (suggested order)
1. Get the user's in-game results -> mark spec lines "in game: PASS" or fix what broke.
2. Then Phase 2: Spec line 9 (window navigation), one feature at a time, tests first.
