# UbermocForever — Testing Checklist

**Created:** 2026-11-05  
**Version:** v0.x (Checkpont 1 + Checkpont 2 applied)  
**When to test:** After `/reload` once the game update finishes.

---

## Section A: Addon Installation

| # | Test | Expected Result |
|---|------|-----------------|
| A-1 | `/ubf debug` in chat | Toggles `debug=true/false`. Message displayed. |
| A-2 | `/ubf selftest` in chat | Prints "selftest passed" or lists failures (no lua errors). |
| A-3 | Open Character Sheet with addon loaded (no commands yet) | No lua errors, addon does its background work without crashing the game. |
| A-4 | Open the addon options panel via `/ubf options` or UI button | Options frame opens; you can see layout settings, legend style pickers (Letters/Forever). |

**Result grid:**
```
[ ] A-1   [ ] A-2   [ ] A-3   [ ] A-4
Comments: ____________________________________
```

---

## Section B: Controller Input Report

| # | Test | Expected Result |
|---|------|-----------------|
| B-1 | `/ubf pad` in chat | Reports your controllers (device name, button count) or "no gamepad found". |
| B-2 | Move the left stick / right stick while running `/ubf pad` report | Report should show current device if any. No errors. |

**Result grid:**
```
[ ] B-1   [ ] B-2
Comments: ____________________________________
```

---

## Section C: Checkpont 1 — Context Detection Engine

> This is the poller that watches which Blizzard frames are visible and classifies your current "context" (SPELLBOOK, BAGS, NPC, etc). You change context by opening/closing game windows.

| # | Test | Expected Result |
|---|------|-----------------|
| C-1 | `/ubf context` in **any** context with no addon frames open | Prints `context: NONE`. No errors. |
| C-2 | Open the **SpellBook**, wait ~1 sec, run `/ubf context` again | Should print `context: SPELLBOOK`. No errors. Close SpellBook (press Escape), repeat — should drop to `NONE`. |
| C-3 | Open your bags → `/ubf context` | Prints `context: BAGS`. Close bags → drops to `NONE`. |
| C-4 | Talk to an NPC that opens **GossipFrame** → `/ubf context` | Should print `context: NPC`. Close gossip → `NONE`. |
| C-5 | Open **Profession frame** (Cooking, Enchanting, etc) → `/ubf context` | Should print `context: PROFESSIONS`. Close → `NONE`. |

**Result grid:**
```
[ ] C-1   [ ] C-2   [ ] C-3   [ ] C-4   [ ] C-5
Comments: ____________________________________
```

---

## Section D: Checkpont 2 — Native Binding Hints (NEW — BINDINGOVERLAYS)

> Bindings are the text shown on UI elements that tells "press this key for this action". This checkpont adds overlay hints to Blizzard frames — no custom art.

### D1: SpellBookFrame Overlays
| # | Test | Expected Result |
|---|------|-----------------|
| D1-1 | Open SpellBook → wait 1–2 sec | You should see small key-text overlays on each visible spell button. The font should look like other UI elements (same family/color/size as your set). |
| D1-2 | Switch pages in the SpellBook (click page buttons) | Overlays update to the new page's visible slots. Old ones disappear. No lua errors on page changes. |
| D1-3 | Close SpellBook (Escape), re-open it | New overlays appear correctly on reload of the frame. Same as D1-1 behavior. |

**Result grid:**
```
[ ] D1-1   [ ] D1-2   [ ] D1-3
Comments: ____________________________________
```

### D2: Bag Slot Overlays
| # | Test | Expected Result |
|---|------|-----------------|
| D2-1 | Open Bags → wait 1–2 sec | Each visible bag slot gets a small key-text overlay on its left edge showing the backpack pickup key. |
| D2-2 | Close bags, re-open them with fewer/more slots than before | Updates correctly — no stale overlays on old slots. |

**Result grid:**
```
[ ] D2-1   [ ] D2-2
Comments: ____________________________________
```

### D3: NPC / Gossip Frame Overlay
| # | Test | Expected Result |
|---|------|-----------------|
| D3-1 | Talk to an NPC with gossip text (not a quest giver) → wait 1–2 sec | A hint overlay appears near the bottom of the gossip frame showing your interact key. |
| D3-2 | Close gossip, open a **quest giver** → wait 1–2 sec | Hint overlay appears for the quest-give frame too (different from gossip hint). |

**Result grid:**
```
[ ] D3-1   [ ] D3-2
Comments: ____________________________________
```

### D4: Action Bar HotKeys
| # | Test | Expected Result |
|---|------|-----------------|
| D4-1 | Have Layout enabled (check `/ubf context` or options) → look at action bar buttons | Each visible action button shows its bound controller key in the hotkey text (below the icon). If your layout binds `PADY` → `ACTIONBUTTON1`, you should see "Y" or equivalent. |
| D4-2 | Rebind something via the Blizzard Key Bindings panel, then reload — check again | The action bar shows your NEW binding, not a stale one. |

**Result grid:**
```
[ ] D4-1   [ ] D4-2
Comments: ____________________________________
```

---

## Section E: Cross-Framework Behavior (combined tests)

| # | Test | Expected Result |
|---|------|-----------------|
| E-1 | Open SpellBook → close bags while still in SpellBook | Context stays SPELLBOOK (Bags didn't replace SpellBook). No errors. |
| E-2 | Rapidly toggle open/close same frame 5 times | No memory leak or lua spam. Same correct context/overlays each time. |
| E-3 | `/ubf selftest` while in SPELLBOOK context | Test reports pass; no warnings about "frame not found" from overlay code. |

**Result grid:**
```
[ ] E-1   [ ] E-2   [ ] E-3
Comments: ____________________________________
```

---

## Section F: Game-Specific Compatibility

| # | Test | Expected Result |
|---|------|-----------------|
| F-1 | Load in **Forever** (TOC 16001), do `/ubf context`, open SpellBook → check overlay text appears | Works without lua errors. Overlays use native font. |

**Result grid:**
```
[ ] F-1   [ ] F-2
Comments: ____________________________________
```

---

## Summary of What Each Checkpont Adds

### Checkpont 0 (v0.10.1 base — already existed)
- Layout system (`Layout.Apply()`): sets controller bindings via `SetOverrideBinding` for action bars
- Labels module: shows Xbox/PlayStation/Switch button glyphs on frames
- Legend UI: displays controller key art + label for current context
- GamePad input detection via `C_GamePad.ButtonIndexToBinding()`
- Cursor system: gamepad pointer mode, window tracking

### Checkpont 1 (committed as `05fe45e`) — Context Detection Engine
- Polls visible frames ~10×/sec → classifies into COMBAT, SPELLBOOK, BAGS, NPC, PROFESSIONS, MENU, NONE
- Lists registered context listeners via `/ubf context`
- Fires listeners synchronously on every transition (used by modules to know "what I'm looking at now")

### Checkpont 2 (COMMITTED as `953b4f7`) — Native Binding Hints
- Overlays spellbook/bags/NPC/menu frames with binding text hints
- Action bar HotKey force-refresh after every layout change
- Uses only native Blizzard FrameString objects (`NumberFontNormalSmall`, `SystemFont_Shadow_Small/Large2`)
- Zero custom textures, zero `CreateFrame("FRAME")` art — purely text overlays that inherit player's font/color/scale

### Checkpoint 5 (v1.0.1, this pass) — Rogue layouts + fixes found in the restart
- `Layouts/Rogue/default.lua` (Lua, never JSON): per-spec spell lists, three-bar template,
  `show_only_active_bar` on. Spell IDs taken from the forever branch's own `TrackedCooldowns.lua`
  — no guessed IDs. The spec keys are the legacy table numbers (259/260/261), but the live
  API in this build reports NEW-range spec IDs (an Outlaw reads 1488 in-game), so the loader
  matches the spec by NAME (label) instead.
- Layout load is fixed: it now runs on `PLAYER_LOGIN` (it was silently skipped before),
  detects the active spec via `C_SpecializationInfo.GetSpecializationInfo` (matched by name),
  and keeps only spells the character knows (`C_Spell.GetSpellInfo`). The log line after login
  says how many spells matched and which spec was used.
- `/ubf layout spells` prints the verified list with the names the game resolves them to.
- Binding hints now start on login (they were dead code — the reason the hints never appeared).
  Bag hints use the branch's real bag frames (`ContainerFrameCombinedBags`, `ContainerFrame1+`).
- Self test: the action-bar pad-glyph line is now **information** (the engine reports the
  keyboard key until the pad is engaged, then the pad key — same binding set, verified in-game).
  The pad-binding registration itself is still a hard check ("layout main bar bound").

**Open question (not implemented, no verified API in this branch):**
- Assigning the layout's spells to action-bar slots: `SetActionBarSlotAction` and
  `C_ActionBars` do not exist in the forever branch; the only verified slot API is
  `C_ActionBar.PutActionInSlot(slotID)` (quick-keybind reorder). Until a verified
  assignment API is found, place the spells from `/ubf layout spells` on your bars by hand.

---

## Section G: Checkpoint 6 (v1.0.2) — Context-Aware Transitions

**What changed:** while a game frame is open (spellbook, bags, professions, menu,
NPC dialog) your plain paddle presses reach the **utility/secondary bar first** and
the paddles snap back to your normal (combat) bars the moment the frame closes.
Combat always wins — entering or leaving combat applies instantly, never debounced.
Rapid open/close is debounced 200 ms so bindings never land half-applied.
Binding-hint overlays fade in over 0.1 s using the game's own animation API
(verified: `CreateAnimationGroup` + `Alpha` animation exist on this build;
`TweenFrame` does NOT — do not use it). New command:
`/ubf transitions [on|off|status]`.

**Tests (out of combat unless noted):**
| # | Action | Expected |
|---|--------|----------|
| G1 | Note which bar your plain paddle reaches, then open the SpellBook and wait ~1 s | Paddle now reaches the SECONDARY bar (spells/utility) first; no lua errors |
| G2 | Close the SpellBook | Paddle reaches your normal primary/combat bar again, immediately |
| G3 | Open SpellBook and close it 4–5 times fast within ~2 s | No stuck/mixed bindings — ends on the normal bars; `/ubf transitions status` shows a consistent live bar set |
| G4 | Open the SpellBook, then start combat (attack something), then leave combat | Combat bars apply instantly on entering combat; normal bars restored on leaving |
| G5 | `/ubf transitions off`, open SpellBook, close it | Paddle bar does NOT change while transitions are off; `/ubf transitions on` restores behaviour |
| G6 | Open SpellBook / Bags / Gossip NPC / Game menu | Hint overlays appear with a quick fade-in (not a hard pop) and look native |

**Open questions (recorded, not implemented):**
- **Steam Overlay / Big Picture:** no API on the `forever` branch reports overlay
  or Big Picture state (checked — every "overlay" hit is spell activation,
  portraits or minimap insets). Per the main spec we do NOT guess Steam APIs and
  do NOT hide addon UI on an overlay. Revisit if a verified reporting API appears.
- **Outlaw tertiary bar showed 0 spells** in the 2026-11-06 baseline (combat
  state during the test run, per the user — not a layout gap). Re-verify the
  tertiary count for Outlaw OUT of combat: `/ubf selftest` prints the per-bar
  spell lists.

---

## Notes for Testing
1. **Check `/ebuf debug` first** to see if anything crashes silently. If `/ubf debug` toggles on and you see lua errors in chat, note which ones and when they occur.
2. **Overlays are lightweight `FONTSTRING` objects — they should look like part of the game UI**, not glued-on (no border, same font as action button text).
3. If an overlay doesn't appear but context says it should: check that you're on the right page in SpellBook, or the bag frame is actually showing slots.

---

*Created by ubermoc for testing after game updates. Keep this file alongside your addon and tick off each test as completed.*
