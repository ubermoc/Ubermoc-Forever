# HANDOFF — Ubermoc Forever (2026-11-13, phase 2 done offline)

## Done this session (phase 2: menu page + bind screen + window navigation)
- Options page now lives in the game's own Settings menu (Settings.RegisterAddOnCategory / RegisterVerticalLayoutSubcategory "UbermocForever Binds" / RegisterAddOnSetting + CreateCheckbox). The old "Enable UbermocForever" checkbox is gone everywhere; Core.lua defaults have no `enabled` and Options.lua deletes it from old saved data. `/ubermoc` opens the page via Settings.OpenToCategory.
- Bind screen (Bind.lua): rows + Clear / Defaults / Close buttons, operable with controller only — d-pad moves a highlight, PAD1 acts, PAD2 closes. RegisterVerticalLayoutSubcategory category is stored as ns.bindsCategory for later deep-links.
- Nav.lua (new): pure model (NavMove/NavActivate/focus) + per-window invisible mover Buttons `UbermocForeverNavMover_<window>_up/_down` whose OnClick does move + claim + redraw; claims are SetOverrideBindingClick on the WINDOW's own frame: PAD1 -> highlighted control, PADDUP/PADDDOWN -> movers, PAD2 -> Close/Goodbye. Maps for MerchantFrame (MerchantFrameTab1/2 verified names) and GossipFrame (options read live from GossipFrame.GreetingPanel.ScrollBox:GetFrames(), GoodbyeButton). Combat refuses to open nav; closing a window clears its claims.
- Spec suite now **60 of 60 PASS** (`luajit /home/ubermoc/Downloads/ubermoc-harness-v2/wow/behavior.lua UbermocForever.toc Spec` from the addon folder). New spec files: Spec/R-2.1-settings-page.lua (4), R-2.2-bindscreen-nav.lua (5), R-2.3-window-nav.lua (10).
- `check` ended CHECK OK (round 3): base checks pass, 60/60 tests, all 9 citations verified (5 Settings-API ones second-sourced by https://warcraft.wiki.gg/wiki/Settings_API; PLAYER_LOGIN, MerchantFrameTab1, GOSSIP_SHOW, GOSSIP_OPTIONS_REFRESHED flagged single-source in the report).
- Installed into the real game: install.sh + verify_install.sh print **INSTALLED OK** (9 files, version 0.1.0; old copy kept as UbermocForever.old).

## What to test (in game — the only real proof left)
1. `/reload`. No popup needed this time (enabled flag removed); layout applies as before if you accepted it earlier.
2. `/ubermoc` → the UbermocForever page appears inside the game's Settings list with the "Controller navigation in windows" checkbox and an "UbermocForever Binds" subcategory. With a controller: can you reach and toggle it? (Whether Blizzard's own settings UI is gamepad-navigable is unverified on our side.)
3. Talk to a vendor: d-pad up/down should move a highlight over Merchant/Buyback tabs + Close, PAD1 picks, PAD2 closes. Same with an NPC gossip window (options + Goodbye). If NO highlight appears at all, the offline-unverified assumption that CLICK override claims fire for PAD keys failed → we switch mechanism (that is the key phase-2 question).
4. `/ubermoc binds` fully operable with d-pad + PAD1/PAD2; pressing a button while a row is highlighted binds it; conflicts refuse with a chat message.
5. `/ubermoc selftest` then `/reload` — all green.

## Known problems / not verified
- Whether SetOverrideBindingClick claims fire for PAD keys with Blizzard's gamepad UI off: no offline way to prove; flagged in Nav.lua header; test 3 above decides.
- Single-source citations (offline Blizzard copy only): PLAYER_LOGIN, MerchantFrameTab1/2 names, GOSSIP_SHOW / GOSSIP_OPTIONS_REFRESHED.
- Spec lines R-1.11..R-1.14 stay NO TEST by agreement (quest windows / snap-to-relevant / reward choice deferred).

## Next steps
- User's pad results decide phase-2 PASS marks in REQUIREMENTS.md; then intake round for phase 3 (deferred spec lines).
- No git repository exists in this folder — nothing can be committed; if the user wants history, init a repo first. .bak copies exist (Bind.lua.bak).
