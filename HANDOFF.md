# HANDOFF: Ubermoc Forever (2026-11-13 17:25)

Probe round 1 done and installed. The next session starts by READING THE PROBE DATA the user produces, then fixing from that data. No fake-world frame tests, no guessing.

## State
- Phase 1 (spec 1-4): WORKS in the real game (user 2026-11-13 11:42). Untouched this round except Layout/Nav guards.
- Phase 2 (settings page, bind screen, window nav): still NOT proven in game. This round added the diagnostic + two fixes from the HANDOFF plan; the rest waits for data.
- Commits: 3223777 (probe round 1) + 38cbaef (requirements notes), pushed to origin/main. Installed into the game folder, INSTALLED OK v0.1.0. CHECK OK at 61/61 offline tests.

## What was built this round
- `Probe.lua` (new): `/ubermoc probe` writes `db.probe` to SavedVariables: settings category state (registered/id/numSettings/stale navWindows), Esc-menu buttons + AddButton exists, per-window records on vendor/gossip open (NavOpenCount, map maker's exact pcall error, every control id/exists/shown/disabled), pad presses at our listener frame (armed ONLY by the probe command), key state at logout.
- `EscMenu.lua` (new): "UbermocForever" button in the Esc menu right under Options; hook on AddButton keyed on GAMEMENU_OPTIONS; opens Settings via C_Timer.After(0,...) (taint rule); PLAYER_QUITING/LOGOUT cancel pending open.
- Nav.lua: no navWindows check (automatic); maker() wrapped in pcall; exposes ns.NavOpenCount / ns.NavIsNavigating for the probe.
- Options.lua + Core.lua: navWindows checkbox and default removed; stale saved value deleted on load.
- Spec updated: R-2.1 no-nav-toggle-setting + stale-nav-flag-deleted, R-2.2 nav-automatic-no-toggle.

## What the user must do (next round trigger)
1. /reload, log in — expect green "loaded." line, NO red errors.
2. Esc menu: check for the new "UbermocForever" button under Options; select it with d-pad + A; report whether the Settings page opens and what it shows.
3. `/ubermoc probe`.
4. Open a vendor, talk to an NPC; press d-pad and A/B inside both windows.
5. Esc -> Options: is there an UbermocForever entry in the left list? What does its page show?
6. `/reload` (SAVES the data), then say "tested".
Then read `WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua` -> `probe` section yourself before touching code.

## Fix order once the data is in (from the previous HANDOFF, unchanged)
1. settings page contents; 2. Esc-menu entry issues if any; 3. automatic navigation end-to-end; 4. the nil-name map keying fix ONLY if `window.GossipFrame.makerError` confirms it (key by frame, not name).

## Open questions the data may not settle -> ask_user_question with options
- Why navWindows had been saved false (may never be known; harmless now).
- Whether pad presses reach addon frames at all when Blizzard's gamepad UI is off (probe answers; if not, R-2.3 needs a different mechanism — discuss before building).

## Rules that bit this session
- check's citation verifier: NAME token must appear within 4 lines of the ref AND in the fetched online page; refs must be real files under uisource; `online` URLs only count if fetched with get/find in the SAME session (earlier-session gets do not register — use single_source wording instead, it is accepted).
- The Spec runner loads .toc files, so Probe.lua runs offline: never arm a pad listener at load (Spec R-1.4 "no-icons-shown-yet").
- replace_lines needs exact line numbers from recall/read; edit refuses unread files and non-unique strings.

## Files
`Core.lua`, `Options.lua`, `EscMenu.lua` (new), `Layout.lua` (works, untouched), `Nav.lua`, `Bind.lua`, `DefaultsDump.lua`, `Probe.lua` (new), `Selftest.lua`, `Tests.lua`, `Spec/`, `REQUIREMENTS.md`. Not released; version stays 0.1.0.
