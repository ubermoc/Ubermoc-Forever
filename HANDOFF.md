# HANDOFF — Ubermoc Forever (2026-11-13)

## Done
- ROOT CAUSE of "the vines are wrong": override bindings on an addon-owned frame never FIRE in plain mode (user's dump 3: keyProbe count=0). The working mechanism, proven by the user's own `WTF/Account/FAQJOO/bindings-cache.wtf`, is SAVED bindings: `SetBinding(key, action)` + `SaveBindings(GetCurrentBindingSet())`.
- Layout.lua rewritten: 58 rows (54 bound + PADFORWARD/PADPADDLE1/2/3 kept free), Blizzard PAD key names only, chord pages SHIFT->MultiBarBottomLeft / CTRL->MultiBarRight / CTRL-SHIFT->bar3, chord copies of TARGETNEARESTFRIEND/ENEMY/JUMP exactly as in the user's file. d-pad order fixed (PADDLEFT=AB5, PADDUP=8, PADDRIGHT=7, PADDDOWN=6).
- Bind.lua: press-to-bind accepts chord spellings ("SHIFT-PAD2"); combat guard; conflict check; ClearOne/Reset operate on saved bindings only, never touch keys outside our layout.
- Harness fake world (`ubermoc-harness-v2/wow/behavior.lua`) fixed: an action holds ANY number of keys (the old two-keys eviction was wrong — user's JUMP = 7 keys).
- Offline spec suite: **41 of 41 PASS** (`luajit .../behavior.lua UbermocForever.toc Spec`, run from the folder with the .toc).
- Installed into the real game: install.sh + verify_install.sh print INSTALLED OK (8 files, version 0.1.0).

## What to test (in game — the only real proof left)
1. `/reload` → accept the popup ("changes your SAVED key bindings"). Your existing binds are identical, so applying is idempotent.
2. Press every button: d-pad casts 5/8/7/6, face buttons 1-4, shoulders target friend/enemy, triggers AB12/AB10, PADPADDLE4 jumps, PADBACK opens world map. SHIFT+shoulder should also target (chord page).
3. `/ubermoc selftest` then `/reload` — all green.
4. `/ubermoc binds` → pick a row → press a button; `/ubermoc unbind` to clear everything.

## Known problems / not verified
- In-game firing of every row is NOT proven yet (needs the user's pad).
- `check` could not verify its citation bookkeeping this session (it only trusts URLs fetched in the same check round); code, specs and install all pass. Last full check: 41/41 tests, base checks OK.

## Next steps
- After the user's press test passes: mark R-1.1..R-1.8 "in game: PASS" in REQUIREMENTS.md notes; then start phase 2 (spec lines R-1.9+ window navigation — no tests written yet).
- Commit + push once CHECK OK is achieved (check keeps rejecting citations on bookkeeping grounds; see Known problems).
