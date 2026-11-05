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

---

## Notes for Testing
1. **Check `/ebuf debug` first** to see if anything crashes silently. If `/ubf debug` toggles on and you see lua errors in chat, note which ones and when they occur.
2. **Overlays are lightweight `FONTSTRING` objects — they should look like part of the game UI**, not glued-on (no border, same font as action button text).
3. If an overlay doesn't appear but context says it should: check that you're on the right page in SpellBook, or the bag frame is actually showing slots.

---

*Created by ubermoc for testing after game updates. Keep this file alongside your addon and tick off each test as completed.*
