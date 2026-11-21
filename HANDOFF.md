2026-11-21 (local model, branch `local-model/x-item-use`, 1.3.153, offline tests only, untested in the game): the use
spell lookup `C_Item.GetItemSpell` is `MayReturnNothing` (claim C147), so `hasUse` in `Ubermoc-Forever/ItemMenu.lua` now
also accepts the item's own `Use:` tooltip line read through `GetItemByID` (claim C149). This is what the user reported:
Crippling Poison - item `3775`, spell `173555` in the game's generated weapon-buff data (claim C150) - got no use-on-weapon
entries while other items did. The rule is general, not for that item alone: every item with a `Use:` tooltip line counts,
and potions (subclass 1), food (5) and an item with no spell and no use line still get nothing. `/ubf item` now prints the
spell id the game gives and what X resolves to on that slot, so it can be read in the game. Offline test: `ALL TESTS PASSED`,
`check_lua` `PASSED` with `UBF_RESEARCH`.

2026-11-20 (local model, branch `local-model/x-item-use`, 1.3.152, offline tests only, untested in the game): X on a bag
slot now does the game's own right click on every item in it. `Ubermoc-Forever/ItemMenu.lua` `M.rightClickAction` no
longer answers "nothing" for the item types the Y menu handles (poisons, armour kits, oils, stones, enchants) or for bags:
any slot item goes through the secure `item` action, which equips when `C_Item.IsEquippableItem` is true and
`C_Item.IsEquippedItem` is false and otherwise uses it - the same call the game's right click ends with. Sources: the game
right click ends with `C_Container.UseContainerItem` (`Mainline/ContainerFrame.lua`:1604-1612, claim C138), the secure
`item` action (`SecureTemplates.lua`:418-440, claim C140), the refused stored delegate (`SecureTemplates.lua`:557-565,
claim C141), the vendor sale and the buyback tab (`ContainerFrame.lua`:1543-1550, claim C145), the class numbers
(claim C142), a poison as consumable subclass `Other` 8 (claim C143), `GetContainerItemInfo` (claim C146) and its `itemID`
(claim C144). The `tools/smoke_test.py` case now expects the `item` action for a recipe, a gamepad slot, an armour kit
(class 8), a bag (class 1) and a poison (class 0 subclass 8), and the legend line says `Use` for a kit and a poison; the
vendor, the buyback tab, the plain click and the mail are unchanged. What the user reported from the game: pressing X did
nothing at all, including on a hearthstone, and his `/ubf item` on item 10918 (Wound Poison) reads class 0, subclass 8,
equip INVTYPE_NON_EQUIP_IGNORE, has a use, used on another item false. Not verified in the game: what the game does when it
uses an armour kit or a poison - only the user can say. Offline tests and the Lua checker pass.

2026-11-19 (Ubermoc, branch `ubermoc/glow-and-defaults`, 1.3.145, offline tests only, untested in the game): a yellow glow
(`ButtonHilight-Square`, ADD blend, `UF.HIGHLIGHT.glow` colour) over each layer button in the options window
(`Options.lua` `b.ufGlow`), shown only on the active layer (the `RefreshOptions` loop sets it with `SetShown`), so the layer
in use is visually distinct beyond the pressed-button state. The author's current settings are now the new defaults for a
brand-new install: `UF.SEED` in `Core.lua` adds `plates` (name-only enemy and friendly, health, percent, quest, questText,
friendlyLevel), `vendor`, and `platerange` On, and `chat.editTop`; `Nameplates.lua` and `PlateRange.lua` nil-check defaults
are flipped to On to match; `UF.SEED.fade.gbar` idle is 0.2 and `xpall` no longer hides. The default-settings case in
`tools/smoke_test.py` is updated and a new case proves a brand-new install defaults plate range to On and applies it at
login. Offline tests (`python3 tools/smoke_test.py`) and the Lua checker pass. Not verified in the game yet: the glow on
screen. Time for this task could not be measured (the context was replaced from a prior handoff before any record here).

2026-11-19 1.3.141 (built by the local model as 1.3.139 on `local-model/optimize`, merged into main as 1.3.141 by Ubermoc, offline tests only, untested in the game): six performance changes in the always-on tickers — GameNav.lua (reused window and open-menu buffers, bag frames found in the single ContainerFrame pass, the open menus counted once per update, the right stick scroller looked for once per frame), Fade.lua (reused situation table, the mouse-over check called with the key so the tick builds no closure per key), GamepadBar.lua (names, signature parts and the shown flag call hoisted out of the tick), Aim.lua (the last size, fraction and height kept as numbers instead of a string signature, the cursor call without a closure). Two new cases in `tools/smoke_test.py`. Offline tests and the Lua checker only — nothing here was seen in the game. Also: `docs/LOCAL-MODEL-NOTES.md` no longer writes a literal FAKE marker in prose (the gate read it as a marker with no claim).
2026-11-19 (local model, branch `local-model/trigger-claim`, 1.3.140, offline tests only): X (the mod's right click) on a
bag item. The game's right click on a bag button is a protected action run by that button, and the secure `click` action
refuses a `clickbutton` stored by our code (`SECURE_ACTIONS.click`, SecureTemplates.lua:557-564), which is why X did nothing
in the bags. X now uses the string actions ItemMenu already proved work: `type = "item"` for the item's own use (a recipe,
a hearthstone), and a `/click <name> RightButton` macro at a vendor when the slot has a global name; an unnamed gamepad bag
slot has no name to click, so X keeps no action there. Armor kits, poisons, oils, stones, enchants and bags keep the Y menu
as their way (the user wants that). `GameNav.lua` `G.xAction(f)` builds the attributes and `G.xLabel(f)` makes the legend
say what X can do (`Use`, `Right-click`, `Train`, `Take all`, or nothing). Sources in `docs/RESEARCH-NAVIGATION.md`, case in
`tools/smoke_test.py`; offline tests and the Lua checker pass. Not shown in the game yet by the user: X on a recipe, on a
hearthstone, on an armor kit (must do nothing), the legend label, a vendor sell on a named slot. The user reports
everything working on 2026-11-19, so 1.3.140 was released on offline tests only.
Time for this task: 08:13 (first record in `.harness/proof.json`) to 10:58, 2 h 45 min, of which 5.7 s were `proof run`
executions; the part before the first record cannot be measured (the context was replaced).

Confirmed in the game by the user 2026-11-19: everything through 1.3.135 (the "are you sure?" question, the question
layouts, the legend layout, A and B inside Yes and No, the no-chat-line change, A answering the replace-enchant question),
plus the friendly nameplate level (1.3.136, drawn by PlateLevel.lua) and Y on a bag slot in the gamepad bag window (1.3.138).
He also reports the trigger fix working; the four observations asked for are in `docs/RESEARCH-NAVIGATION.md`.

2026-11-19 (local model, branch `local-model/trigger-claim`, 1.3.139, untested in the game): the triggers are no longer
claimed for every open window — `GameNav.lua` `triggersUsable()` takes them only where they have something to do (a stack
of side tabs, or a scrollable list under the highlight) and `G.syncTriggers()` re-checks on every highlight move, so a
spell bound to the right trigger fires again when nothing needs paging or scrolling. This was the user's report: after
coming out of stealth his stealth button (the right trigger) did nothing until Escape was pressed twice, with no panel
open. Sources in `docs/RESEARCH-NAVIGATION.md`. The other way this can happen (the game still in cursor mode with no
panel open) is not fixed here — see that file, and the four observations asked of the user.

Confirmed in the game by the user 2026-11-18 (evening): 1.3.138 works, including the friendly player level on nameplates (the 1.3.136 version, drawn by PlateLevel.lua to the left of the name; the 1.3.137 move onto the game's level frame was REVERTED because it did not show) and Y on a bag slot in the gamepad bag window (GamepadBagBar slots have no global name, found by their slotName key in ItemMenu.lua bagBarSlot). Released: 1.3.138 on GitHub (v1.3.138) and uploaded to CurseForge (waiting for approval); CurseForge description rebuilt from docs/DESCRIPTION.md with 10 new screenshots (custom nameplates, all five options pages, cinematic camera). Not done: a chat window screenshot (none taken yet), the unused gravestone nameplate shot. The CHANGELOG may still list a 1.3.137 entry that describes the reverted move. Workflow used: worktrees in ../Ubermoc-Forever-work, merged with tools/merge-branch.sh, installed with tools/install.sh, pushed to main.

Confirmed in the game by the user 2026-11-18: everything through 1.3.129 (the user tested all of it and reported that it works). Earlier the same day: everything through 1.3.125, and the game draws no nameplate farther than 45. Before that, 2026-11-17: everything through 1.3.103 (see AGENTS.md). Released: 1.3.129 (GitHub and CurseForge). Untested in the game: 1.3.136 (level on friendly player nameplates), 1.3.135 (A answers the game's replace-enchant question again), 1.3.134 (one question only: ours for poisons, the game's for kits; no chat line), 1.3.133 (A and B inside the Yes and No buttons), 1.3.132 (tidier legend layout), 1.3.131 (layout of the question: pictures beside Yes and No, Continue? apart), 1.3.130 (the "are you sure?" question before replacing a poison, oil, kit or enchant). Read this whole
file before doing anything. It says what the project is, what the user wants, what is built, what is proven and what
is not, and what to do next.

**Newer notes are in `AGENTS.md` (current state, release routine for GitHub and CurseForge, gotchas). Where this file disagrees with it, `AGENTS.md` wins.**

**Where it stands (read this first):** addon version **1.3.85** (micro menu/bags/XP bar marked as set on the Bars page while the gamepad layout is on; 1.3.76: gamepad layout: black and white face button pictures with a colour option, end caps option; 1.3.75: gamepad layout: pictures over the top edge, cooldown edge line instead of the swipe, red out-of-range overlay, micro menu/bags/XP bar default places, untested; 1.3.74: the gamepad layout, one bar for the controller, Bars page with its own fading, bound-button pictures, forced-hidden art and a Move bars (Edit Mode) button, written by Ubermoc, untested in the game; 1.3.72: title fix in the marker menu; 1.3.71, built by the local model and confirmed in the game by the user: 1.3.71: our own marker menu built with the game's own menu code (`MarkerMenu.lua`), so the game's marker submenu is no longer built from our hook; untested in the game. 1.3.70: secret-value guard in Fade.lua after 340 errors; 1.3.69: submenu opening throttled after a flood of warnings on an enemy player, cause of the repeating press unknown; 1.3.67: markers via the secure raidtarget action; the user confirmed everything through 1.3.67 works in the game on 2026-11-17; 1.3.66: menu entry click target written inside securecallfunction; 1.3.65's frame-reference idea broke A on menus and was removed; untested; no OnEnter on menu entries after the SetRaidTarget taint, untested; submenu opened through securecallfunction after the SetRaidTarget taint report; A opens submenus of the game's menus, untested; 1.3.61: target menu: the key right-clicks TargetFrame itself, eight keys; a soft interact target (skinning) keeps the key, /ubf targetmenu report; untested; the user does not run Ubermoc UI together with this addon; 1.3.58: interact on a hostile or non-interactable target opens its unit menu, `TargetMenu.lua`, untested in the game; 1.3.57: Chat page: every chat part has Fade by itself, hidden until the chat is used; the user confirmed everything through 1.3.57 works in the game on 2026-11-17 (nothing from 1.3.48 on is untested any more); 1.3.56: edit box only; 1.3.55: Chat page, the third options page: chat settings and per-part opacity live there, not on the Fading page, tabs never auto-open ; 1.3.54: a faded chat window and the edit box appear on new lines and while typing, then wait and fade, `F.reveal`/`F.hold` ; 1.3.53: chat lines fade by themselves, `Chat.lua`, new options row, ; 1.3.52: universal mouse-over opacity on the Fading page; 1.3.51: Fading expanded to about 110 elements with parts, scrolling list, copy/paste/apply, /ubf fade ; 1.3.48: A on a gear slot opens the equipment flyout, GameNav.lua flyoutOpener; 1.3.41: Fade.lua + FadePage.lua: fading of interface elements by situation, a second page in the options window in the game, notes docs/RESEARCH-FADE.md; 1.3.27: release to cast for ground spells was built (1.3.27 to 1.3.32) and removed in 1.3.40 because it worked inconsistently; 1.3.25: Aim.lua: white aim dot for ground spells + aim distance; see docs/RESEARCH-GROUND-SPELLS.md; 1.3.21: DialogButtons.lua draws quest/gossip buttons as controller strips; 1.3.18: cinematic camera while talking to an NPC, `Cinematic.lua`, notes in docs/RESEARCH-CINEMATIC.md; not yet tested in the game; /ubf cinema on|off; 1.3.17: spell binding is by pressing the button combination: it goes to the slot that combination triggers, or a free combination gets the first empty slot on a visible bar and a bind, or the game asks Replace/Keep it; nothing of ours is anchored to action bars and no tooltip runs on them because that tainted the bars; user-confirmed in the game 2026-11-16; 1.3.6: the right stick scrolls lists and text (stick API as Ubermoc UI uses it), highlight-driven scrolling moves the list minimally and scrolls at the edge, X takes everything in a mail (AutoLootMailItem), the highlight is a glow, the Y menu reads where an item goes from its use text (M.targets: armor kits, scopes), /ubf scan author tool; all confirmed in the game by the user on 2026-11-16; 1.3.5: quest and gossip windows start on their first option or the Accept/Continue/Complete button (G.dialogStart), B is Decline, X trains in ClassTrainerFrame (G.trainButton); unconfirmed in the game; 1.3.4: the vendor Sell entry right-clicks the item button (or picks it up onto the vendor) because using the item equipped it; 1.3.3: X is its own secure button (UbermocForeverGameRClick) and has no target in question windows, menus and place mode: a right click on StaticPopup buttons asserted in GameDialog.lua; 1.3.2: nothing is offered for ranged weapons (slot 18); 1.3.1: poisons confirmed in game as class 0 subclass 8 via /ubf item, so consumables are told apart by a Use: line that mentions a weapon (tooltip data); 1.3.0: Y menu rewritten (ItemMenu.lua): items used on weapons (rule in usedOnItems, unconfirmed in game: /ubf item prints class/subclass), Disenchant/Prospect/Mill, worn-item menu lists bag items usable on it, any button with GetItemLocation; tooltip shown beside the highlight on the side with room; 1.2.9: the Menu: Left/Right option and /ubf menu command are gone; the item menu always picks the side with room; 1.2.8: the item menu picks a side with room: the chosen side when it fits, else the other, always clamped to the screen; 1.2.7: buttons with no OnClick (the map filter drop-down: WorldMapTrackingOptionsButtonTemplate, a DropdownButton) get their OnMouseDown/OnMouseUp run on A/X, as ConsolePort GetEmuClick does; errors go to /ubf check; 1.2.6: drop-down buttons (DropdownButtonMixin opens on mouse DOWN) are toggled with SetMenuOpen on A/X; open menus (Menu.GetManager, DropDownList1-3) are modal, the highlight jumps in, B closes them, highlight returns to the button; 1.2.5: the legend bar wraps onto more rows so it is never wider than the window it sits under; 1.2.4: windows list now includes UIPanelWindows and UIChildWindows (the open letter, guild pop-ups) and a window that just opened takes the highlight; 1.2.3: side tabs are plain Frames from LargeSideTabButtonTemplate (no Click): found by SelectedTexture+TabGlow+OnMouseUp, pressed by running OnMouseUp; /ubf tabs lists what was found; 1.2.2: triggers step the vertical side tabs (profession tabs etc.) when a window has them, else scroll; 1.2.1: item menu side option: "Menu: Left/Right" button on the options window and /ubf menu left|right; the highlight now jumps into the item menu so B closes it; 1.2.0: B closes the window the highlight is in then jumps to the next open one; bumpers step the tab group nearest the highlight (TabSystem, Tabs arrays, rightProfessionTabs, PanelTemplates); legend sits under that window; Y menu also on worn items (Use, Pick up) and spells ("Bind to action bar": picks the spell up, highlight moves over the action bars, A places it with C_ActionBar.PutActionInSlot, B cancels); all untested in the game. 1.1.2: a legend bar at the bottom of the screen lists what each button does over the game windows, Y only on bag items; 1.1.1: Y on a bag item opens `ItemMenu.lua`: Use or Sell, Pick up, Delete (asks twice), Sort bags; spells not yet. Before that 1.1.0, in use and working per the user: `GameNav.lua` moves a drawn gold highlight around the game's own windows: D-pad moves, A/X secure left/right click, B close button, bumpers tabs with wrap, triggers scroll, auto-scroll to the highlight, modal question windows; `/ubf nav off` turns it off; design in docs/RESEARCH-NAVIGATION.md sections 5 and 7; Nav.Push now takes a second table of secure keys. Also 1.0.9: windows stay open in combat, the player closes them. 1.0.7 added the combat rule: windows refuse to open in combat, buttons retaken after combat; untested in the game. Navigation research is in docs/RESEARCH-NAVIGATION.md; the user chose highlight + real clicks for the game's own windows, next feature) (numbering continues from CurseForge's 1.0.5; 0.3.x work: Start is now a stepped button ported from Ubermoc UI, `Start.lua`, bound on all four layers with the game's own Escape off; the legend has LB/RB "Prev hold"/"Next hold" and the bumpers wrap; window widened to 650. Unconfirmed in the game. Supersedes the "Start alone = Exit" notes below.), last commit `4a10dfe` on the branch below. The window,
the picker, Start = Exit and the D-pad navigation are all in. The user has been testing in the game from phone photos
and found real bugs each round; the **latest fix (0.2.1) is not yet confirmed in the game**. The first thing to do is
ask the user to update, check the version shown in the window, and report what the picker does.

- **Repo:** `ubermoc/Ubermoc-Forever` (public). **Branch:** `ubermoc/affectionate-cray-lhlr0j`. **PR:** [#1](https://github.com/ubermoc/Ubermoc-Forever/pull/1), draft, not merged.
- **If you cannot see this file on the default branch**, it is on the branch above. Read it from there.
- The addon is `Ubermoc-Forever/`. Everything else (`tools/`, `docs/`, `README.md`) supports it.

## 1. What the user wants

A **controller-first mod for World of Warcraft: Forever** (the Forever client only, **not Midnight**), designed for the
**Steam Deck and Steam Controller**, and also working with PlayStation 5, Xbox and Nintendo Switch controllers.

Their rules, in their words as closely as can be kept:
- **Original Blizzard assets only.** "Nothing drawn, nothing added." The mod must use the exact same design and layout as
  World of Warcraft and "look like it's been a part of it by design".
- **No guesswork.** "We're going to look everything up 100%." Work methodically, **one feature at a time**.
- Local checkout of Ubermoc UI: `~/Downloads/Ubermoc/Ubermoc-UI` (moved there from `~/Downloads/Ubermoc-UI` on 2026-11-16).
- A lot of the working code already exists in **Ubermoc UI** (`ubermoc/Ubermoc-UI`, Marcos's own addon, 30,000 lines).
  Port the same binds and ordering from it. They are the same author. Do not change Ubermoc UI from here (its own
  `Ubermoc.md` says so).
- The name shown in the game is **"Ubermoc Forever"**, not "Controller".
- They **do not use Blizzard's built-in controller interface** (the game's "Gamepad UI"). They need to move around
  our windows **"like it's native"**.
- They want short, copy-paste steps. **They use the fish shell** (`; and`, not `&&`; `env VAR=x cmd`, not `VAR=x cmd` in older fish).

### Feature 1 (the one being built): detection, default binds, options, legend, game menu
1. Detect the controller and **prompt** the player to set the default key binds.
2. Default binds copy Ubermoc UI's layers and order.
3. **Options from day one:** change any bind, clear a bind, and a **reset to default** button.
4. A **legend**: first button (A) = select/accept, second (B) = decline/back, third (X) = clear (binds page only), fourth (Y) = menus, **changes to fit the page**.
5. Reached from the **game menu, directly above Blizzard's Options**, in Blizzard's own style.

More features come after this one. The user has not yet said which.

## 2. What is built (all on the branch)

| File | Job |
| --- | --- |
| `Ubermoc-Forever.toc` | `## Interface: 16001`, `SavedVariables: UbermocForeverDB`, load order below. |
| `Core.lua` | Shared table `UbermocForever` (`UF`), saved settings, `/ubf` (`/ubf check`), and a **self-check** run after login (the Checks button / `UF.reportChecks`). |
| `Layouts.lua` | Controller sets (`xbox`, `ps5`, `ps3`, `switch`, `steam`) with `name`, `short` and text labels; `UF.glyph(pad, set)` returns the **game's own** button picture text. |
| `Detect.lua` | Detects the controller from `C_GamePad` (ported from Ubermoc UI). Sets `UF.detected`, `UF.deviceName`, `UF.hasPaddles`; `UF.activeSet()`. |
| `Binds.lua` | `UF.applyDefaults(set)` (four layers: none, Shift button, Ctrl button, both), `UF.setBind`, `UF.actionName`, `UF.isModifierButton`. |
| `Legend.lua` | The legend row of button pictures and words. |
| `Nav.lua` | Controller movement inside our windows (see section 4). |
| `Prompt.lua` | The first-run question (the game's own popup), once per character. |
| `Options.lua` | The window (`ButtonFrameTemplate`) and the action picker: an **Exit (Escape)** line, then the game's binding categories, each **closed until chosen, one open at a time** (plus / minus art from the game). |
| `Menu.lua` | Adds the "Ubermoc Forever" button above Options by hooking `GameMenuFrame:InitButtons`. |
| `tools/install.sh` | Finds the Forever `AddOns` folder (Steam Proton prefixes incl. SD card, `~/Games`, `/Applications`) and installs. `--link`, `--uninstall`, or pass a path. |
| `tools/setup-research.sh` | Builds `~/Downloads/WoW Forever Tools and Research` with Blizzard's Forever UI source and reference addons. |
| `tools/smoke_test.py` | Offline test against a stub of the game (needs `lupa`). |
| `docs/RESEARCH.md` | Sourced facts about the Forever client, tagged by how sure they are. **Read it.** |

TOC load order: `Core, Layouts, Detect, Binds, Legend, Nav, Prompt, Options, Menu`.

Defaults (same as Ubermoc UI, except Start, which is Exit): Steam Controller/Deck uses R4 as Shift and R5 as Ctrl; every other controller uses the
left trigger as Shift and the right trigger as Ctrl. Right bumper targets the nearest enemy, left bumper the nearest
friend. Start alone is Exit (the game's own Escape), Select is the map. Interact and jump are on L4/L5 (stick clicks on pads without back
buttons).

## 3. What is proven and what is not

**Proven in the game (user photos, 2026-11-15):** the addon loads; the window opens built on the game's own frame; the
controller pictures are the game's own; a Steam Deck / Steam Controller is read as `steam` (the game reports the device
as "Steam Controller"); the action picker opens.

**Proven only offline (`tools/smoke_test.py`, stubbed game):** the files compile and load; detection and the three
picture styles; both default layouts; the first-run prompt; the picker choosing an action; the highlight walking the
whole list in order without wrapping; A, B, X, Y; the question windows taking A and B; the combat driver is registered;
the controller button label stays short. The stub **cannot** show how the game really behaves.

**Not yet confirmed in the game (do these first, in this order):**
1. **The category list in the picker (0.2.1).** 0.2.0's list never appeared for the user because a binding with no category threw while it was being built (fixed in 0.2.1, and any later failure now prints a line in chat starting "The list of actions could not be…"). Ask: does Change show "Exit (Escape)" then categories, all closed? Does A open one and close the others?
2. **Start alone = Exit.** The user's rule is that Start with no modifier is the game's own Escape. The default now does that (Start unbound, `GamePadEmulateEsc` = `PADFORWARD`), and the Start row reads "Exit (Escape)" on any layer with no bind. Unconfirmed: that pressing "Reset to default" really makes Start behave right. Ask for the **Checks** output: it prints the four `GamePadEmulate*` settings and what Start is bound to on each layer.
3. **The "Ubermoc Forever" entry in the Esc menu.** No photo yet. It relies on `layoutIndex = Options.layoutIndex - 0.5`. Unverified.
4. **The D-pad highlight, A, B, X, Y and the bumpers** (0.1.x rewrite). The three problems reported earlier (button label spilling, face buttons firing the action bars, list jumping to the top) were fixed but none confirmed.
5. **The first-run prompt** and **applying the defaults** on a real character; releasing the buttons in combat.
6. The Checks list: whether every row passes on Forever.

## 4. Things learned the hard way (do not relearn these)

- **The game's virtual cursor does not click with A.** Its click buttons are CVars `GamePadCursorLeftClick` (default R2) and `GamePadCursorRightClick` (default R1). With A untaken, A fires `ACTIONBUTTON2`. Ubermoc UI takes A itself. Our `Nav.lua` takes A, B, X, Y, the D-pad and the bumpers with `SetOverrideBindingClick`.
- **Do not move the pointer by code.** `SetCursorPosition`'s units are undocumented; the first attempt (ported calibration) misbehaved. Nav now moves a **highlight** (`LockHighlight`) and presses with `button:Click()`.
- **Override bindings cannot be changed by addon code in combat.** The owner frame is `SecureHandlerStateTemplate` with `RegisterStateDriver(owner, "combat", "[combat] 1; 0")` and `_onstate-combat` calling `self:ClearBindings()`. Same as Ubermoc UI.
- **Forever has its own controller interface** (`InputUtil.IsGamepadUIEnabled()`, `Blizzard_GamepadSmartNavigation`). It only runs in that mode and refuses insecure callers, so addons cannot use it. The user plays with it **off**. Forever++ warns that addon-opened menus can break focus when it is on.
- **A binding can have no category at all** (`GetBinding` returns nil; the game files it under "Other", see `Blizzard_SettingsDefinitions_Frame/Keybindings.lua`). The 0.2.0 category list used the category as a table key and threw on the first one, so the categories and their toggles never appeared (the game hides Lua errors by default). Fixed in 0.2.1; the test stub now includes a category-less binding, and a failure building the list is printed in chat. **Do not assume a user is on an old build when they report a problem: check the version shown in the window and reproduce first.**
- **`GetBinding(i)` returns the category as the name of the header text** (`"BINDING_HEADER_MOVEMENT"`), not the text. Look it up as a global.
- **A raised frame level alone did not put the picker above the rows.** It needs `SetFrameStrata("FULLSCREEN_DIALOG")`, and the list underneath is hidden while it is open.
- **Native layout rules** (`ButtonFrameTemplate`): header band under the title; content inside `Inset` (top left `4,-60`, bottom right `-6,26`); bottom bar holds `MagicButtonTemplate` buttons (bottom right `-6,4`, next one `RIGHT` to `LEFT` offset `-1`). Every line of text is set to one line (`SetWordWrap(false)`) so nothing wraps into the next row.
- **`/run` and `/dump` are blocked** in Forever (`C_AddOns.GetScriptsDisallowedForBeta()`). Never ask the user to type scripts. Use the in-addon Checks.
- **Exit is the game's emulated Escape, not a bind.** `GamePadEmulateEsc` holds the button (or `NONE`). The user saw that with both modifiers held, Start acts as Escape even though our window said "Not bound" there. So a row whose button is the game's Escape button and has no bind on that layer reads "Exit (Escape)" (`UF.isExitRow`). `UF.setExit(pad, combo)` sets the button and clears that layer's bind; X on an Exit row calls `UF.clearExit()`. Why it acts as Escape there is **unverified**: ask for the Checks output, which prints the four `GamePadEmulate*` settings and Start's action on each layer. Ubermoc UI warns the game's native Escape can use up presses on a controller so the menu never opens; our default Start is still `TOGGLEGAMEMENU`. A row reading `CLICK UbermocMenu:LeftButton` is Ubermoc UI's Start bind, now shown as "Game menu (Start)".
- **Decided by the user (0.2.0): Start alone = Exit.** `bindSystem` leaves Start unbound and sets `GamePadEmulateEsc` to `PADFORWARD`; the Start row reads "Exit (Escape)".
- **Bump `## Version` in the TOC with every change** and mention it to the user. The window shows it (grey, in the header line), Checks prints it and `tools/install.sh` prints it after installing. The user had been testing an older build without knowing; this lets both sides tell.
- **`GamePadEmulateShift/Ctrl/Alt/Esc` and `GamePadEnable` are not in Blizzard's Lua.** They are carried over from Ubermoc UI, which runs them.
- **The paddle buttons used as Shift/Ctrl show as `P1` / `P3`** (the game's `Gen_Paddle1/3` pictures). They are R4/R5 on the Deck. The user has not asked to change this. Offer to add "R4"/"R5" text beside the pictures.
- **Test-stub traps:** the stub must treat lowercase field names as plain data, track Show/Hide and fire OnShow/OnHide, and provide `Click`, `GetTextWidth`, `Inset`, `CloseButton`. Add to the stub when new code needs it. When a stub-only failure appears, check whether the real game would behave differently before changing the addon.

## 5. Known gaps and the next steps, in order

1. **Get the user's in-game results** for section 3 (items 1 to 6). Ask for photos, the version shown in the window and the Checks output. Fix what they show. **Reproduce before you decide what is wrong.** Twice the user was right and the first guess ("you are on an old build") was wrong.
2. **Port per-character binds.** Ubermoc UI gives each character its own copy (`charBinds` in `Controller.lua`). Ours changes the account-wide binds while the prompt asks once per character.
3. **Picker usability:** the list is every action the game offers (long). Consider grouping or search once it is confirmed to work.
4. **PlayStation Back/Social labels:** Ubermoc UI says Back = "Create", Social = "Touchpad"; Blizzard's `KEY_PADBACK_SHP` is the touchpad picture. One is wrong. Check on a real PS5 pad.
5. **Release process is not set up.** The Ubermoc Warcraft Mod Updater installs from the **latest non-prerelease GitHub release** of `ubermoc/Ubermoc-Forever` with a zip whose top folder is `Ubermoc-Forever/` (see `Ubermoc-Warcraft-Mod-Updater/py_modules/ubermoc_wow/service.py`, `DEFAULT_ADDONS`). Ubermoc UI's `Ubermoc.md` has its release routine (version in the TOC, `CHANGELOG.txt`, tag `vN`, `git archive --prefix=...`, GitHub release, CurseForge). None of that exists here yet, and `gh` is not available in the cloud session. Ask before doing any release.
6. **Decide the licence on purpose:** detection and the default layout are ported from Ubermoc UI (All Rights Reserved, Marcos); this repo is MIT. Same author, his call.
7. **The next feature.** Ask the user which one. Candidates from Ubermoc UI: radial menus, a pointer or D-pad movement for the game's own windows (`PadCursor.lua` is the reference), controller-friendly dialogue.

## 6. How to work with this user and this environment

- **The cloud session cannot reach the user's computer.** `list_computer_folders` offers nothing usable (`Ubermoc-UI` on a computer named "Ubers" is not offered to cloud sessions). Never claim to have installed anything on their machine. Give them commands to run.
- **Update flow on their machine** (fish), from `~/Downloads/Ubermoc/Ubermoc-Forever`:
  `git pull` then `bash tools/install.sh`, then restart the game (or `/reload`). They have hit "no such file" errors from not being on the branch or from `git fetch` without `git pull`. Tell them to `git pull`.
- **Their folders:** repo clone `~/Downloads/Ubermoc/Ubermoc-Forever`; Downloads is `/home/ubermoc/Downloads`; research folder from `bash tools/setup-research.sh` is `Downloads/WoW Forever Tools and Research`.
- **They send phone photos of the game screen.** Look at them carefully; they are the real test. Describe what you see and fix it.
- **Reference sources** (clone fresh; the cloud container is temporary): Blizzard's Forever UI is `Gethe/wow-ui-source`, branch `forever` (build 1.60.1.70938 when written). The API dump is `Thunderz96/forever-addon-kit` (`data/forever_api.json`). Sourced notes are in `xIGBClutchIx/ForeverPlusPlus` (`docs/forever-api.md`). `bash tools/setup-research.sh` fetches all of them. **Look things up there before writing code.**
- **Run the offline test before every push:** `pip install lupa` in a venv or scratch folder, then `python3 tools/smoke_test.py`. It should end with `ALL TESTS PASSED`.
- **Git rules for the session:** develop on `ubermoc/affectionate-cray-lhlr0j`; commit messages end with the attribution lines the session gives; keep the PR a draft; the session is subscribed to PR #1 events. Do not merge or approve. Do not put model names in commits or PR text. Ask before anything outward-facing (releases, comments, uploads).
- **Be honest about status.** Say what is proven in the game, what only passes offline, and what has not been tried.

### Phone link
The phone link is gone: the folder and the systemd user service that ran a remote worker on the handheld were deleted.
Each worker works in its own work copy under `~/Downloads/Projects/Ubermoc-Forever/Project Support/Ubermoc-Forever - Worker Copies`; nothing runs as a background service.

### Lessons about working with this user
- They test fast and report from the game. When they say something doesn't work, believe them and reproduce it. Two reports that looked like user error were real bugs (the category list, the Escape row).
- They are exact about how the game should behave ("Start alone should equal Exit"). Do not change their stated defaults without asking, and ask one specific question when a rule is ambiguous.
- They want short copy-paste steps, one command per block, fish syntax. They have hit "no such file" errors from `git fetch` without `git pull`, and from running commands outside the repo folder. Say the folder and the exact commands.

## 7. First thing to say to the user in the new session

Summarise the "Where it stands" paragraph and section 3 in a few lines, say which fixes are untested in the game, and ask
them to run `git pull` and `bash tools/install.sh` (the last line should say version 0.2.1 or newer), restart the game,
then send photos of: the Esc menu, the main window (the version is in the grey text in its header line), the picker
after pressing Change, and the Checks output.
