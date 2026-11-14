# HANDOFF: Ubermoc Forever (2026-11-13 23:30)

Round 4 done: all four symptoms from the user's in-game test are fixed, CHECK OK, pushed, INSTALLED OK. The next session starts by READING THE USER'S REPORT of tests (a)-(d) below — do not change code before it.

## State
- Phase 1 (spec 1-4): WORKS in the real game (user confirmed earlier). Untouched this round.
- Phase 2 (R-2.1..R-2.4): offline PASS (70/70), NOT yet proven in game — awaiting the user's round-5 test.
- Commits: ... b1000ff (round 3) + **0c4d344** (round 4, pushed to origin/main). Installed, INSTALLED OK v0.1.0. CHECK OK (base checks + 70/70 tests; all citations verified single-source — the wiki `online` second source kept being rejected as "never fetched" despite get succeeding, so single_source naming Blizzard's shipped files is the accepted route).

## What was built this round (commit 0c4d344)
1. **EscMenu.lua** — our button's callback is now INLINE (`Settings.OpenToCategory(ns.settingsCategory:GetID())`), exactly like Blizzard's Options button (GameMenuFrame.lua:166-171 wrapper, :189). The C_Timer.After(0,...) deferral + pendingOpen flag + PLAYER_QUITING/LOGOUT guards are GONE — they raced Blizzard's panel lifecycle (dead click; suspect for the Exit Game error too).
2. **Bind.lua** — bind rows are no longer UIPanelButtonTemplate Buttons (user saw "red bars, no words"). Rows are plain named Frames `UbermocForeverBindRow<i>` with self-drawn FontStrings (`__nameText` left, `__keyText` right) + our own highlight textures: full gold bar = selected row (`Interface\Buttons\ButtonHilight-Square`), outline = d-pad highlight (`Interface\Buttons\UI-Listbox-Highlight2`, ChatConfigFrame.xml:22). `ns.UpdateRowLabels` refreshes texts; forward-declared (reviewer flagged definition order). Clear/Reset/Close keep UIPanelButtonTemplate.
3. **Nav.lua** — mover Buttons have exactly ONE handler (OnClick; OnKeyDown removed) and claim() always `SetPropagateKeyboardInput(false)` while navigated: one press = one move. New narration block: `ns.Speak(text)` gated on GetCVar("accessibilityScreenNarrationEnabled"), voice/rate/volume via pcall(GetCVarNumberOrDefault, "accessibilityScreenNarrationVoice/SpeechRate/SpeechVolume"), strips `|c%x+`/`|r`, dedupes repeats, StopSpeakingText then SpeakText. NavDraw speaks the focused control's `labelFor(c)` (labelFor MUST be defined before NavDraw — crash lesson).
4. **Spec/R-2.5-narration.lua** (new, 5 tests) + Spec/R-2.3 grid test updated (asserts NO OnKeyDown on movers). REQUIREMENTS.md: two new Design-decision lines (rows-as-Frames/one-handler; narration-is-ours because NarrationUtil.lua:122 gates on C_Glue.IsOnGlueScreen). known-mistakes.json entry 29 `wow-double-key-handler-on-binding-mover`.

## What the user must do (next round trigger)
/reload, then:
- (a) Esc -> UbermocForever: Settings opens straight onto our page; every row shows name + key as readable text; d-pad/PAD1/PAD2 work.
- (b) Esc -> Exit Game: confirm popup, NO Lua error. If an error still shows: `/ubermoc debug` IMMEDIATELY and report — the exact error text was never captured, this fix is educated/unverified.
- (c) Vendor: one d-pad tap = exactly ONE highlight move.
- (d) Settings > Accessibility > Enable Screen Reader ON + vendor: highlighted items spoken by name; OFF: silence.

## Fix order once the report is in
- Red bars persist -> Bind.lua look code (applyRowLook / UpdateRowLabels).
- Narration silent -> check GetCVar names (single-source, Blizzard files only), then C_VoiceChat.SpeakText args.
- Exit Game still errors -> `/ubermoc debug` output FIRST, then fix from the real stack.
- Multi-move persists -> Nav.lua claim()/mover code; verify SetOverrideBindingClick owner/priority.

## Open / left
- Slash help says "binds" vs actual subcommand "bind" (minor, untouched).
- Phase 4 lines 11-14 not started (gossip/quest windows nav polish; maps already exist in Nav.lua from round 3).
- `Bind.lua.bak` sits untracked in the repo — never commit it.

## Rules that bit this session
- check citations: local Blizzard copies drift by one line between snapshots — re-grep the exact single line before quoting. `name` must appear within 4 lines of ref. warcraft.wiki.gg `online` URLs were rejected "never fetched" in EVERY round despite successful `get` calls (downloads exist under ubermoc-research/downloads) — for private Blizzard files use `single_source` naming the shipped file; that is accepted.
- Reviewer flags forward-looking calls even when runtime-safe: add an explicit forward declaration or a comment proving the call happens after load.
- replace_lines restores .lua when the range clips an `end`; edit refuses stale reads — re-read the region, then edit.

## Files
`Core.lua`, `Options.lua`, `EscMenu.lua`, `Layout.lua` (works, untouched), `Nav.lua`, `Bind.lua`, `DefaultsDump.lua`, `Probe.lua`, `Selftest.lua`, `Tests.lua`, `Spec/` (+R-2.5-narration.lua new), `REQUIREMENTS.md`. Not released; version stays 0.1.0.
