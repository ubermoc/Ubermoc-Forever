# Research: moving around the game's interface with a controller

Written 2026-11-15. Nothing here is from memory: every claim names the file and line it came from, in the copy that
was read. **Read** means the code was opened and read. **Not tried** means it has not been run in the game.

Sources read (all cloned fresh today):

| Short name | Repo and commit | Licence |
| --- | --- | --- |
| **UbermocUI** | [ubermoc/Ubermoc-UI](https://github.com/ubermoc/Ubermoc-UI) `09d87d3` | All Rights Reserved, Marcos (same author as this repo) |
| **ConsolePort** | [seblindfors/ConsolePort](https://github.com/seblindfors/ConsolePort) `5d526b2` (2026-11-13) | Artistic License 2.0 |
| **ConsolePortNode** | [seblindfors/ConsolePortNode](https://github.com/seblindfors/ConsolePortNode) `b86ed65` | **GPL v2** (header of `ConsolePortNode.lua`) |
| **Blizzard Forever UI** | [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) branch `forever`, `bebcb6b`, build 1.60.1.70938 (`version.txt`) | Blizzard's |

**Licence warning.** This repo is MIT. ConsolePortNode is GPL v2, so its code cannot be copied here. ConsolePort is
Artistic 2.0, which has conditions on copying. The approach in both can be learned from and written fresh; do not paste
their code. UbermocUI is Marcos's own: his decision whether to port code from it.

## 1. How UbermocUI does it (it uses the game's own cursor)

Everything below is in `UbermocUI/PadCursor.lua` unless another file is named.

**The idea.** While one of the game's windows is open, the addon turns on the game's real cursor
(`SetGamePadCursorControl(true)`, `update()` line ~635) and *moves that cursor* from button to button with the D-pad.
A and X then click for real (`SimulateMouseClick`, `click()` ~319). Header comment lines 5-10.

| Piece | Where | What it does |
| --- | --- | --- |
| Which windows count | `P.OpenWindows` L90-109 | Walks `UISpecialFrames`, `GetUIPanel(left/center/right/doublewide/fullscreen)`, the game menu, the bags. |
| Which windows it leaves alone | `OWN_WINDOWS` L54-62, `P.OwnOpen` L60-73 | Its own windows, the question popups (`StaticPopup1-4`), ready checks and similar keep a separate drawn pointer. |
| When it is active | `P.Wants` L116-121 | Not in combat, game cursor engine on, a window is open, none of the "own" windows is open. |
| Finding buttons | `P.Nodes` L225-233, `visit` L207-223 | Recursively visits children (depth 14, max 900), keeps `Button`/`CheckButton` that are mouse enabled and visible, stores centre and rectangle. |
| Choosing the next button | `P.Pick` L236-251 | Candidates must be at least 6 pixels along the direction. Score = distance along + 2 x distance across. Lowest wins: "straight ahead beats off to the side". |
| Moving the cursor | `P.MoveTo` L280-288, `checkLanding` L290-302 | Calls `SetCursorPosition`; the units are corrected by reading `GetCursorPosition` back on the next frame. |
| Where the cursor is | `P.Snap` L304-317 | On a button: pick the neighbour. Not on one yet: go to the nearest. |
| Bumpers | `onButton` L535-567, `Tabs.Target` L192-197, `tabsFromFrame` L143-168 | Look for `frame.tabs`/`selectedTabID` or `numTabs`/`selectedTab` up to depth 6, go to the next/previous tab, **wrapping round**. The tab is clicked on button *release* (`onButtonUp` L526-533). |
| Triggers | `onButton` | `SimulateMouseWheel` to scroll. |
| B | `P.Back` L342-362 | Closes the top thing in order: a question popup (`StaticPopup_EscapePressed`), the settings panel (`SettingsPanel.Close(true)`), then `CloseMenus` and `CloseAllWindows`. It deliberately avoids the game's full Escape action "because it also stops casting and clears the target and can use up the press". |
| Taking the buttons | `syncInput` L619-633 | `input:EnableGamePadButton(true)` with `OnGamePadButtonDown` / `Up` scripts; released when no window is open. |
| The game's own click buttons | `manageClicks` L573-596 | The game clicks with CVars `GamePadCursorLeftClick` (default R2) and `GamePadCursorRightClick` (default R1). It sets them to `NONE` while it has the buttons and puts them back after. |
| Combat | `onCombatStart` L655-670 | Releases the buttons and closes every window. |

### Accept and decline questions (`Extras.lua`)

- Lines 3732-3745: a popup is a confirmation when its `which` is `BIND_ENCHANT`, `REPLACE_ENCHANT` or
  `ACTION_WILL_BIND_ITEM`; "button 1 = accept, button 2 = decline" (the comment says so).
- `updateConfirm` L3767-3810: shows a small bar under the popup, a green A "Accept" and red B "Decline", and creates two
  `SecureActionButtonTemplate` buttons (`UbermocCursorAcceptBtn`, `UbermocCursorDeclineBtn`) whose `clickbutton`
  attribute is `popup:GetButton1()` / `GetButton2()`. A and B are bound to them with `SetOverrideBindingClick` for as
  long as the popup is up, then returned to normal.
- Deleting a good item asks you to type DELETE; `Extras.lua` L4549-4580 fills it in for you when a controller is used.

### The Y menu on a bag item or spell (`Extras.lua`)

- `openItemMenu` L3117. The menu is for **bag and bank items and spellbook spells only**; on anything else it says so.
- Entries (L3140-3200): **Use / equip** (or **Sell** when a vendor is open), **Equip in a bag slot** (for bags),
  **Pick up / move**, **Add to the utility ring** (usable items), **Delete** (asks "Really delete?" first),
  **Sort bags**, and profession actions **Disenchant / Prospect / Mill** when the spell is known.
- *Use* and *Sell* are secure buttons (`type=item` or a `/click <slot> RightButton` macro) because "the game only lets a
  real button press use an item" (comment, L3147).
- Y is handed over by `onButton` (PadCursor L560-565) to `API.cursorItemMenuFrom`.

### Held buttons while a window is open (`Extras.lua` `setPadBindings`, L3281-3330)

D-pad, bumpers, triggers and A/X/B/Y are taken with `SetOverrideBindingClick(owner, true, key, <button name>, "LeftButton")`
and given back on close. A modifier button (Shift/Ctrl/Alt emulation) is never taken (`isPadModifier` L3271).
Binding a key from the Key Bindings page onto the same job wins over the default face button.

## 2. How ConsolePort does it (it draws its own highlight and never moves the mouse)

- Header, `ConsolePort_Cursor/View/Cursor.lua` L1-6: "Creates a cursor used to manage the interface with D-pad.
  Operates recursively on frames and calculates ... node priority and position on screen."
- **Finding nodes:** the separate library ConsolePortNode. `IsRelevant` L248-257, `IsInteractive` L241-246,
  `IsDrawn` L263-274, recursive `Scan` L339-356, clipping check for scroll frames `CheckClipping` L319-337. Frames can
  carry attributes `nodeignore`, `nodepriority`, `nodesingleton`, `nodepass` (header L23-30).
- **Choosing the next node:** `NavigateToBestCandidateV3` L720-744 weighs each candidate by distance **and the angle off
  the direction pressed** (`weight = 1 + offset/DIVDEG`), with `NavigateToClosestCandidate` L746 as the fallback.
- **Clicking:** the cursor does *not* click by moving the mouse. For each node it focuses, it **re-binds A to a real
  click on that node**: `Cursor:SetClickButtonsForNode` L624-641. Clickable nodes get `Input:SetButton(button, self, node, true, "LeftButton")`
  (a secure click on the node); dropdowns get `GetMenuClick` L366-376 (`node:SetMenuOpen`); nodes with only mouse-down
  scripts get `GetEmuClick` L337-361 (runs their `OnMouseDown`/`OnMouseUp`).
- **B (cancel):** `SetCancelButtonForNode` L674-697 finds the node's close button (`node.CloseButton` or `<name>CloseButton`,
  searching parents, `GetCloseButton`/`FindCloseButton` L659-672) and binds B to click it. If the node has its own cancel
  handler (`Hooks:GetCancelClickHandler`, Hooks.lua L93) that is used instead.
- **Questions:** `Controller/Mods.lua` L8-48. When a `StaticPopup` is shown the cursor jumps to its first button
  (`GetButton1`) and remembers the node it left, returning to it when the last popup hides.
- **Y ("special") on a bag item or spell:** `Hooks.lua`. `OnTooltipSetItem` (L257, registered via
  `TooltipDataProcessor.AddTooltipPostCall` L359-364) works out which item the cursor is on and `SetPendingItemMenu`
  L153-160 adds a tooltip line **"Options" with the button's picture**. On the special button, `ProcessInterfaceCursorEvent`
  L19-60 opens `ItemMenu` / `SpellMenu`.
- **ConsolePort's item menu** (`ConsolePort_Menu/View/Popup/ItemMenu.lua`, `SetCommands` L72-130): Equip (with "Replace
  <current item>" per slot), Place on action bar, Add to ring, Sell, Trade, Split stack (n/m), Disenchant, Socket,
  Pick up, Inspect, Delete. A useful checklist next to UbermocUI's.
- **Combat:** `Cursor.lua` L28-38 hides the cursor and releases everything on `PLAYER_REGEN_DISABLED`, and waits a delay
  after combat before coming back (`UIleaveCombatDelay`, doubled when dead, L40-60).
- **Defaults:** `Database.lua` L90-105: left click = A (`PAD1`), right click = X (`PAD3`), special = Y (`PAD4`), cancel = B (`PAD2`).
- **Known safe-click detail:** `Scripts.lua` L1-9: replacing some Blizzard scripts because "original functions become
  taint-bearing when called insecurely".

## 3. What the game itself says (Blizzard Forever UI, build 1.60.1.70938)

All paths under `Interface/AddOns/`.

- **`SetCursorPosition`'s units are documented.** `Blizzard_APIDocumentationGenerated/InputDocumentation.lua` ~L268-284:
  arguments are `uiUnit`, and "Insecure code can only call this once in response to gamepad input hardware events"
  (`RequiresLimitedInput = true`). `GetCursorPosition` (L30-38) returns plain `number`. That mismatch is why UbermocUI
  calibrates. (An earlier note in this repo said the units were undocumented; they are named, only their scale
  relative to `GetCursorPosition` is not spelled out.)
- **`SimulateMouseClick`** (same file, L285-297): `RequiresLimitedInput`, "Effectively the same as SimulateMouseDown plus
  SimulateMouseUp and consumes limited input for both." So **one click per button event**, and both halves are used.
- **Blizzard's own question-window buttons in its gamepad mode** (`Blizzard_StaticPopup/StaticPopupGamepad.lua` L19-37,
  L274-295): bottom face button = button 1 (accept), right = button 2 (decline), left = button 3, top = button 4; a "hold"
  variant for dangerous ones (2 seconds). This is the game's own accept/decline convention, and matches what Ubermoc UI
  does with A/B. It only runs in the game's controller interface, which you play with **off**.
- **The game's own system for taking buttons** (`Blizzard_GamepadSharedUtility/InputBindingStack/InputFunctionBinding.lua` L49):
  `SetOverrideBindingClick(UIParent, true, key, buttonForKey.name, mouseButton)`. Same technique as UbermocUI and
  ConsolePort, in Blizzard's own code.
- **`StaticPopup_EscapePressed`** exists (`Blizzard_StaticPopup/StaticPopup.lua` L846) and is registered as the Dialog
  priority of the game menu's Escape handler (`Blizzard_StaticPopup_Game/GameDialog.lua` L3).

## 4. What is shared, so what we already know works

1. Taking the buttons only while our window is open, with `SetOverrideBindingClick`, released at combat start. **We do this
   already** (`Nav.lua`, proven in the game by your earlier photos for the D-pad highlight, A, B and the bumpers).
2. Clicks that touch protected things (using, selling, equipping) must come from a **secure button**. Both addons say it.
3. Questions: A = accept = button 1, B = decline = button 2 (UbermocUI and Blizzard agree).
4. Bumpers = tabs, wrapping round (UbermocUI `Tabs.Target`).
5. B closes the top layer using the closing steps only, not the full Escape (UbermocUI `P.Back`).
6. Y = a small menu on bag items and spells only. UbermocUI and ConsolePort both do this; ConsolePort tells you with an
   "Options" line on the tooltip.

## 5. Where they differ (the decision)

| | UbermocUI | ConsolePort |
| --- | --- | --- |
| Pointer | Moves the game's **real cursor** with `SetCursorPosition` | Draws **its own highlight**; the mouse stays put |
| Click | `SimulateMouseClick` on whatever is under the cursor | Re-binds A to a **secure click on the highlighted node** |
| Next node | Distance along + 2 x distance across | Distance weighted by **angle** (V3), plus scroll-aware clipping |
| Cost | Needs the unit calibration; one move and one click per event | Needs a full node scan and per-node binding changes |

This repo's own earlier attempt at moving the pointer misbehaved (HANDOFF section 4), and Nav.lua already uses the
highlight-and-`Click()` approach, so the ConsolePort style is the closer fit and the one that handles protected actions
cleanly. **Not decided yet; this is the first question below.**

## 6. What is NOT known yet (needs checking in the game, not assumed)

- Whether the frames the game uses for bags, character, spellbook and the map in **Forever** have the same shape as
  retail (tabs via `frame.tabs` / `numTabs`, `ContainerFrameCombinedBags`, `GetUIPanel`). The Blizzard source is read; the
  behaviour is **not tried**.
- Whether `SetOverrideBindingClick` onto a Blizzard button runs the click without tainting it on Forever. ConsolePort
  and UbermocUI both rely on it; **not tried here**.
- Whether `GamePadCursorLeftClick` / `RightClick` CVars exist in Forever (UbermocUI sets them; HANDOFF section 4 says they do).
- Which popups are "accept or decline" and which are "type something" (DELETE) in Forever's list of `StaticPopupDialogs`.

## 7. Added 2026-11-15: scrolling, tabs, select and close (second pass)

Same sources and commits as above. Read, not tried in the game.

### Scrolling

- **ConsolePort follows the highlight.** `Controller/Scroll.lua` `Scroll:To` L17-39: when the highlight moves to a node
  inside a scroll area, the area is scrolled so the node is centred. Two cases: a classic `ScrollFrame` (sets the
  vertical scroll with a short eased animation, `Interpolate` L83-95; hybrid scroll frames are skipped, L53-57) and the
  newer `ScrollBox` list (`ScrollToElementDataIndex(index)`, found by climbing from the node to the row that is a direct
  child of the box and calling its `GetElementDataIndex`, L63-79). Called from `Cursor:Select` (`View/Cursor.lua` L587).
- **ConsolePort also scrolls on a button.** `Cursor:SetScrollButtonsForNode` (`View/Cursor.lua` L601-620): when the
  highlight is inside something that scrolls, **modifier + D-pad up/down** is bound to two hidden proxy buttons
  (`Scroll.lua` L110-139) that call the area's own `OnMouseWheel` with a repeat while held. "A scroll controller" is any
  frame whose `OnMouseWheel` is the game's `ScrollControllerMixin.OnMouseWheel` (L158-160).
- **The game's own scroll call**: `ScrollControllerMixin:OnMouseWheel(value)`
  (`Blizzard_SharedXML/Shared/Scroll/ScrollController.lua` L93-100) scrolls one wheel step; `ScrollIncrease` / `ScrollDecrease`
  (L113-125) are the calls it makes. So a plain call to the area's `OnMouseWheel` is the supported way to scroll one step
  with no mouse.
- **UbermocUI** scrolls with the triggers using `SimulateMouseWheel` (`PadCursor.lua` L336), which needs the game's cursor
  over the list.

### Tabs

- **ConsolePort has no tab buttons.** A search of `ConsolePort_Cursor` finds no tab handling: tabs are just nodes the
  highlight lands on with the D-pad, and A clicks them.
- **UbermocUI uses the bumpers** (section 1): find the tab list on the open window, step with wrap, click on release.
- **What the game gives us to find tabs** (Blizzard Forever UI `bebcb6b`): the newer `TabSystemMixin`
  (`Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.lua` L310 `SetTab(tabID, isUserAction)`, L350 `GetTabButton(tabID)`),
  and the older `PanelTemplates_SetTab(frame, id)` (`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua` L441) with
  `PanelTemplates_GetSelectedTab` L446. Both kinds exist, so both have to be looked for.

### Select and close

- **Select**: ConsolePort re-binds A to a real secure click on the highlighted node (section 2). We already do the same
  kind of thing with `button:Click()` for our own window; for the game's protected buttons the click has to come from a
  secure button whose `clickbutton` attribute is set to the highlighted button (UbermocUI does exactly this for
  accept/decline, section 1), and that attribute cannot change in combat.
- **Close**: ConsolePort binds B to click the window's own close button (L674-697); UbermocUI `P.Back` calls the closing
  steps in order. The close button way is the more exact one, because it runs the window's own close code.

### What this adds up to (proposal, not built)

1. **Highlight**: our own drawn highlight, moved with the D-pad using the angle-weighted pick (written fresh).
2. **A**: secure click on the highlighted button; **B**: click the window's close button, else the closing steps.
3. **Scroll**: auto-scroll to keep the highlighted row in view (ScrollBox index, or ScrollFrame centring), plus triggers
   (or a held modifier plus D-pad) calling the area's `OnMouseWheel`.
4. **Tabs**: bumpers, found through `TabSystemMixin` first, then `PanelTemplates` (`numTabs` / `selectedTab`), with wrap.
5. **Combat**: everything off in combat, as now.

Still **not known** (needs the game): which of the two tab kinds each Forever window uses, and whether a secure click onto
a Blizzard button taints it.

## 8. Added 2026-11-15: using items on other items, profession actions, tooltips

Sources: the Blizzard Forever UI `bebcb6b` (paths under `Interface/AddOns/`), ConsolePort `5d526b2`, Ubermoc UI `09d87d3`, plus
the web. **Read** = opened and read; **not tried** = not run in the game.

- **How the game applies an item to another item.** Using such an item puts the game into item targeting
  (`SpellCanTargetItem()` / `SpellIsTargeting()`, used in `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua` L1614 and L1861 and
  `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` L631, L1508, L1723); the next click on a worn item or bag item
  applies it. The same thing as a macro is two lines, "/use <item>" then "/use <inventory slot>", with slot 16 the main hand
  and 17 the off hand: confirmed by player macros in a [Blizzard forum thread](https://us.forums.blizzard.com/en/wow/t/sharpening-stone-macro/276382)
  and the [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Sharpening_Stone); not tried here. It runs from a secure macro button.
- **Which items are used on another item** is NOT given by any single game call that was found. The game has
  `Enum.ItemClass.ItemEnhancement` = 8 and, for consumables, `Itemenhancement` = 6 and `ItemenhancementTemporary` = 15
  (`Blizzard_APIDocumentationGenerated/ItemConstantsDocumentation.lua` L284, L313, L322). The rule used is: an item with a use
  spell that is of class 8, or a consumable that is not a potion, elixir, flask, scroll, food or bandage. How Forever
  classifies sharpening stones and poisons could **not** be confirmed (the one database page that might say, metaforge, refused
  the request), so `/ubf item` prints the class and subclass of the highlighted item to check it in the game.
- **Disenchant, Prospecting, Milling**: ConsolePort uses "/cast Disenchant" then "/use <bag> <slot>" (`ConsolePort_Menu/View/Popup/ItemMenu.lua`
  SetCommands) and only for green to epic weapons and armour (`Wrapper.lua` `CanPlayerDisenchantItem`). Ubermoc UI uses spell ids
  13262, 31252 and 51005 (`Extras.lua`). Prospecting needs five ore (trade goods subclass 7) and Milling five herbs (subclass 9):
  those two subclass numbers are from memory of the item data, not from the Forever files. Pick Lock was left out.
- **Tooltip beside the highlight**: the highlighted button's own `OnEnter` runs so each window shows its own tooltip, then
  `GameTooltip` is anchored to the right of the button, or the left when the right has no room (ConsolePort also draws its tooltip next to its
  node: `ConsolePort_Menu/View/Popup/ItemMenu.lua` SetTooltip uses `SetBagItem`). Not tried.
