# Local model report: the marker menu (1.3.71)

Branch: `local-model/marker-menu`. Version 1.3.71, installed with `bash tools/install.sh`; `/reload` in the game.

## What I read

AGENTS.md, `docs/LUA-WOW-GUIDE.md` sections 3 and 8, the last sections of `docs/RESEARCH-NAVIGATION.md`, and the Blizzard copy on disk
(`~/Downloads/WoW Forever Tools and Research/blizzard-ui-source-forever`, build 1.60.1.70938): `MenuUtil.lua` `CreateContextMenu`
(L151-167, returns the proxy), `Menu.lua` the proxy-is-a-menu-frame comment (L74-78), `OpenMenuInternal` closing every other menu
first (L2596-2597), the OnUpdate that closes a menu when its owner is not visible and `ignoreOwner` not being on the proxy API
(L2547-2553), `OpenContextMenu` anchoring at the cursor unless gamepad UI is on (L2623-2645), an initializer's `w, h` setting the
element size (L1031-1037), nil responders allowed (L858-863, L916), `MenuTemplates.lua` `CreateTitle` (Frame element, L294-303)
and `CreateButton` (Button element, `fontString`, L199-204, L305-317), `Compositor.lua:384` `AttachTexture`, the game's marker
entry `UnitPopupSharedButtonMixins.lua` (text, order 8..1 then None L2562-2576; radio + `GetRaidTargetIndex` warning L2582-2628;
icon calls), `TargetFrame.lua` anchor (L675-676) and sprite rows/columns (L691-692), `FrameControlsManager.lua` L248-264 with the
gamepad UI on (`forever-api.md` L167). Every cited line was verified in the copy on disk; notes are in `docs/RESEARCH-NAVIGATION.md`,
new heading "The marker submenu built with the game's own menu code (1.3.71)".

## What I changed

- **`Ubermoc-Forever/MarkerMenu.lua`** (new, toc after `GameNav.lua`), `UF.MarkerMenu`: `M.order()` (game's order, 8 down to 1,
  then None), `M.markerNumber(text)` (None is 0, names map back, anything else or a non-string is nil), `M.menu` (menu frame of
  the last open), `M.open(anchorFrame)`. Owner is `_G.TargetFrame` — the entry we were called from cannot be it (opening closes
  the other menus, so the entry hides, and the OnUpdate closes a menu whose owner is not visible); `open` returns false when the
  target frame is hidden, and GameNav then keeps its old path. Generator: title = the target's name with a guard for a secret
  value (fallback `RAID_TARGET_ICON`), then nine Button elements with the game's icon initializer (sprite sheet cell,
  `fontString` anchored left of the 16x16 texture, returns `width + 60, 20`). No `CreateRadio`, no `GetRaidTargetIndex`.
  Every Blizzard call is guarded or inside `pcall`, so the file loads against the test stub.
- **`GameNav.lua`**: PostClick now takes `entryText(f)` once, records it in `G.lastSub` as before, and for the marker entry
  (`t == _G.RAID_TARGET_ICON`) calls `UF.MarkerMenu.open(f)` instead of the entry's `OnMouseDown` (the old path stays for other
  entries and for when `open` returns false). `G.markerOf` accepts entries inside `UF.MarkerMenu.menu` as well as the game's old
  submenu and delegates text to number to `UF.MarkerMenu.markerNumber`. `markBtn`, `setTargets`, B and X need no change: the
  marker still goes through `UbermocForeverMarkBtn`, PostClick closes the menus after, B closes through the manager proxy.
- **`tools/smoke_test.py`**: three cases beside the existing marker test (which still prints `8,0,nil,nil`): order and every
  text mapping back, `markerNumber("Set Focus")` nil, and `markerOf` for an entry inside our menu (mocked `G.inside`),
  inside neither, inside the game's submenu. Full run: `exit=0`, `ALL TESTS PASSED`.
- Docs kept in step: CHANGELOG entry (marked untested), README and DESCRIPTION line, HANDOFF version note.

## Not verified in the game

Everything: that `open` runs from PostClick without a warning, that the highlight lands on `RAID_TARGET_8` (the title is a Frame
element, not a node), that A on an entry sets the marker through the secure button and closes the menus, that B closes our menu,
that it is placed right of the target frame (`OpenContextMenu` anchors at the cursor and we re-anchor), the title when the target
name is secret, and the assumption that gamepad UI is off (with it on, an addon menu taints the focus manager).

Check first in the game: interact key on an enemy, A on "Target Marker Icon" — the menu should open to the right of the target
frame with the highlight on the first entry, A should set the marker and close the menus with no Lua warning, B closes it. If a
warning appears: `/console taintLog 2`, `/reload`, repeat, `/logout`, read `Logs/taint.log` in the Steam compatdata folder.
