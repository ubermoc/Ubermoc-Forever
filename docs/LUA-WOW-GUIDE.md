# Writing WoW: Forever addon Lua: a guide for coding agents (including small local models)

Read `AGENTS.md` first (what the project is, how to test, how to release). This file is the hard-won Lua and game knowledge.
Rule zero: **never invent an API, frame name or field**. Look it up (section 1), or make the addon report what the game says
(section 7), and say what you could not verify.

## 1. Where to look things up (in this order)
1. **The installed addons**, which are working code for this exact client:
   `~/.local/share/Steam/steamapps/compatdata/2752047377/pfx/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/`
   (UbermocUI, Polestar*, BugSack and others). `grep -rn "SomeApi" .` there first. Example: the stick API
   (`C_GamePad.GetDeviceMappedState().sticks[i]`, `StickIndexToConfigName`, `EnableGamePadStick`) was copied from UbermocUI.
2. **Blizzard's Forever UI source** (`Gethe/wow-ui-source`, branch `forever`) and the API dump `forever_api.json` from
   `Thunderz96/forever-addon-kit`: run `bash tools/setup-research.sh` to download them into `~/Downloads/WoW Forever Tools and
   Research` (that folder was empty on 2026-11-16: run the script). `grep -rn` the source for the template or function name.
3. **Our own notes**: `docs/RESEARCH.md`, `docs/RESEARCH-NAVIGATION.md`, `docs/ITEM-USE-SCAN.md`.
4. **The game itself** through the addon's reports (section 7). The user runs the game; you cannot.
Web sources (warcraft.wiki.gg API pages) describe retail and can differ from Forever. Treat them as hints, confirm in 1 to 4.

## 2. The environment, in short
- Lua 5.1 with Blizzard's additions. No `require`, no `os`, no `io`. Files share the addon table through `local _, UF = ...`.
- Load order is the `.toc` order. A `local` is only visible **below** where it is declared. **A closure that uses a local
  declared further down the file silently reads a global (nil).** This bug cost real time here (`focus` was used by a click
  handler above its `local focus`). Declare shared locals near the top, before any function that uses them.
- `ipairs` stops at the first `nil`. Never build a list like `{ a(), nil, b() }` and loop with `ipairs`.
- `pcall(f, ...)` returns `ok, results...`. `pcall(C_Item.GetItemInfoInstant, id)` gives `ok, itemID, type, subType, equipLoc,
  icon, classID, subClassID`: count the positions. Wrap anything that may not exist in this build in `pcall`.
- `/run` and `/dump` are blocked in Forever. Do not ask the user to type scripts.
- Errors are hidden by default. BugSack/BugGrabber (installed) collect them; the addon reports its own failures with
  `UF.check(name, ok, detail)` (shown by `/ubf check`) and `UF.say(text)` (chat).

## 3. Secure code, taint and combat (the part that breaks addons)
- **Protected actions** (using items, casting, targeting, clicking secure buttons, moving protected frames) cannot run from
  our code. Do them from a **secure button**: `CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")` with
  `type="click"` + `clickbutton`, `type="macro"` + `macrotext`, or `type="item"`. Attributes can only be changed **out of
  combat**; set them whenever the target changes, never in combat.
- **Override bindings** (`SetOverrideBindingClick(owner, true, key, buttonName, mouseButton)`) take a key for our window. The
  owner is a `SecureHandlerStateTemplate` frame whose `[combat]` state driver clears them. Code cannot rebind in combat.
  Windows stay open in combat and the player's own binds come back; the addon must not try to hold keys then.
- **Taint**: anything that runs in our code is tainted. If our code runs a Blizzard frame's script (for example a tooltip's
  `OnEnter` on an action button), or writes to Blizzard tables or frames, the game's own secure code can later fail with
  "blocked", "secret value" or "protected function" errors that are blamed on us. Rules that came from real errors here:
  - Never run `OnEnter`/`OnLeave`/`OnClick` of an **action bar button** or other protected frame from our code.
  - Never anchor our frames to action bar buttons (`SetPoint(..., actionButton, ...)`). Use screen positions instead.
  - Do not write fields on Blizzard frames (`frame.ubfSomething = x`). Keep our data in our own tables.
  - Calling an API from our code that fires events synchronously (e.g. `C_ActionBar.PutActionInSlot`) runs those events'
    handlers inside our tainted call. Keep such calls few and out of combat.
  - Closing or showing Blizzard panels from our code: use `securecallfunction(HideUIPanel, frame)`.
  - A mouse right click sent to a `StaticPopup` button asserts (`GameDialog.lua`): X must have no target in popups.
  - **A frame stored by our code in a secure button's attribute taints the click** (1.3.65). `clickbutton` = a Blizzard frame, set with `SetAttribute`,
    is fine for plain actions, but if the clicked button's script calls a **protected function** (`SetRaidTarget` from the game's menu, found with the taint
    log) the game blocks it and blames us. Do NOT hand it over through a frame reference and a restricted snippet: that stores a frame
    *handle*, and `SECURE_ACTIONS.click` then fails with "attempt to call a nil value" (1.3.65, broke every press). 1.3.66 writes the attribute inside
    `securecallfunction(button.SetAttribute, button, "clickbutton", frame)` instead (hypothesis, check the result with the taint log).
  - Do not run the game's `OnEnter` on **menu entries** (`Menu.lua`, frames with `GetElementDescription`): it is the menu's hover logic.
  - `securecallfunction(fn, ...)` runs a Blizzard function with its own taint, not ours. It does not clean values we stored.
  - `hooksecurefunc` hooks are safe (run after, do not taint the original). Keep them small.
- **Finding the taint source: use the game's taint log, do not guess.** In game: `/console taintLog 2`, `/reload`, repeat the failing action, then `/logout` (the file
  is only written then). Read `Logs/taint.log` (in the game folder next to `WTF`, on this machine under the Steam compatdata folder). Look for "An action was blocked
  because of taint from <Addon>" and the lines just above it: the first stack line is where the thread became tainted. Turn it off with `/console taintLog 0`. Two
  wrong guesses (1.3.62, 1.3.64) cost the user two game tests before the log was read.
- `InCombatLockdown()` before touching any secure attribute, binding or protected frame.

## 4. Frame facts worth knowing
- New drop-downs (`DropdownButton`) open on **mouse down**; a forwarded click does not send it. Run `OnMouseDown`/`OnMouseUp`
  or `SetMenuOpen`. Large side tabs are plain Frames (no `Click`), found by `SelectedTexture` + `TabGlow`, pressed by
  `OnMouseUp`. Newer lists are `ScrollBox` (`GetScrollPercentage`, `SetScrollPercentage`, `GetVisibleExtentPercentage`);
  rows are recycled, so a highlighted row can become another item or hide.
- Windows to scan: `GetUIPanel`, `UIPanelWindows`, `UIChildWindows` (the open letter lives here), `UISpecialFrames`,
  bags `ContainerFrame1..13`, `StaticPopup1..4` (modal). Drop-down menus: `Menu.GetManager():GetOpenMenu()` and `DropDownList1..3`.
- Screen coordinates: `GetCenter`, `GetLeft` are in the frame's own scale. Multiply by `GetEffectiveScale()` to compare frames,
  divide by `UIParent:GetEffectiveScale()` to anchor to `UIParent`.
- Item data: `C_Item.GetItemInfoInstant(id)`, `C_Item.GetItemSpell`, `C_TooltipInfo.GetItemByID(id).lines[i].leftText` (the
  tooltip text, needs the item loaded: `C_Item.RequestLoadItemDataByID` and read a few frames later). Item classes: consumable
  0, weapon 2, armor 4, trade goods 7, item enhancement 8; poisons are class 0 subclass 8.
- Spells: `C_SpellBook.PickupSpellBookItem(slotIndex, bank)` puts a spell on the cursor; `C_ActionBar.PutActionInSlot(slot)`
  places it; `GetActionInfo(slot)` is nil when empty. Slots: bar 1 is 1 to 12 (plus a page offset), bar 2 (`MultiBarBottomLeft`)
  61 to 72, bar 3 (`MultiBarBottomRight`) 49 to 60, bar 4 (`MultiBarRight`) 25 to 36, bar 5 (`MultiBarLeft`) 37 to 48.
  The key bind names are `ACTIONBUTTONn` and `MULTIACTIONBAR1..7BUTTONn`. Ask the game with `GetBindingAction(key)`.
- Keys: a held back paddle can be the game's Shift or Ctrl (`GamePadEmulateShift`/`Ctrl`). Steam Input can also turn a
  paddle into a keyboard key (SPACE, F6). Bind strings are written `CTRL-SHIFT-KEY` (that order). Capture keys with a frame
  that has `EnableKeyboard(true)`, `SetPropagateKeyboardInput(false)`, and an `OnKeyDown` script; **always switch it off again**.
- Controller buttons: A `PAD1`, B `PAD2`, X `PAD3`, Y `PAD4`, bumpers `PADLSHOULDER`/`PADRSHOULDER`, triggers
  `PADLTRIGGER`/`PADRTRIGGER`, D-pad `PADDUP/DOWN/LEFT/RIGHT`, stick clicks `PADLSTICK`/`PADRSTICK`, back paddles
  `PADPADDLE1..4` (R4, L4, R5, L5 on a Steam Controller / Deck).

## 5. Testing without the game
`python3 tools/smoke_test.py` runs every addon file against a stub of the game using `lupa` (a venv; `tools/setup-research.sh`
can make it). It checks logic, not looks. Add a case for every new rule: a function that takes plain tables and returns
values is easy to test (`G.pick`, `G.slotForKey`, `M.targets`). Mocks must be plain tables with the methods the code calls
(`GetParent`, `IsShown`, ...). A stub-only failure may be the stub's fault: check what the real game does before changing
addon code. It must end with `ALL TESTS PASSED`. Then `bash tools/install.sh` and the user types `/reload`.

## 6. Working method that has worked (small steps, honest status)
1. Restate the request in one line. If two meanings are possible and it matters, ask one question.
2. Find the real names (section 1). Write the smallest change. Keep new logic in small pure functions.
3. Add a smoke test, run it, install, bump the version in the `.toc`, add a `CHANGELOG.txt` line.
4. Tell the user what changed, what you did **not** verify, and the exact thing to try in the game. When they report
   a failure, add a chat message or `/ubf` report that shows what the game sent, instead of guessing again.
5. Several guesses in a row means you lack data: build a report or a scan (like `/ubf scan`, which walks item ids and saves
   the game's own tooltip text into `UbermocForeverDB`, read afterwards from the SavedVariables file under
   `WTF/Account/<name>/SavedVariables/UbermocForever.lua` after a `/reload`).
6. Commit with `git -c user.name=Claude -c user.email=noreply@anthropic.com`, push to the branch and `main`. Releasing
   (GitHub + CurseForge) only when the user says so; the routine is in `AGENTS.md`.

## 7. Reports the addon already has
`/ubf check` (self-check results), `/ubf tabs` (tab groups found in the open window), `/ubf item` (class, subclass and
verdict for the highlighted item), `/ubf scan [status|stop|reset|from N|budget N]` (author data scan), `/ubf stick flip`
(reverse right-stick scrolling), `/ubf nav on|off`, `/ubf targetmenu` (interact-key menu: keys, target facts, soft target, what ran), `/ubf fade` (fading elements this game lacks), `/ubf dialog` (quest window). While a spell is being bound, chat shows every key the game sends.

## 8. Mistakes to avoid (all happened)
- **Never assume which addons are enabled.** A folder in `Interface/AddOns` does not mean it runs. 1.3.58 stood down for Ubermoc UI and 1.3.59 switched its settings off, both on a
  wrong guess; the user does not run Ubermoc UI and Ubermoc Forever together. Check the character's `AddOns.txt` or ask.
- A game menu's **submenu opens on mouse down or hover, not on click** (`Menu.lua`): a forwarded click does nothing, so GameNav presses it through the entry's own `OnMouseDown`
  (`securecallfunction`), and finds the submenu by the frame anchored to that entry (the menu manager only lists the first menu).
- The interact key's priority is the game's own (`Blizzard_GamepadActionBars/MainActionBarFrame.lua`, `interactActions`): soft interact target in range first (a corpse to skin, an herb),
  then a lootable or interactable target, then attack. Taking the key for any enemy broke skinning (1.3.58). A context menu needs a visible owner frame with a size and a position.
- Fixing the same bug three times from the source alone: when a cause is not visible in the code, get evidence from the game (a `/ubf` report, BugGrabber, the taint log) before the next change.
- Using a local before it is declared; looping with `ipairs` over a list with holes; counting `pcall` return positions wrong.
- Calling a function that may not exist in Forever (`GetItemInfo` for a name) without a guard: one failure stopped a whole scan
  and was counted again every frame. Guard calls, count errors, and never let one item stop the rest.
- Re-picking the highlight after every scroll step (it pulled the list back); using `ScrollToElementDataIndex` (it jumped
  to an end); falling back to a window's first button (its exit) when a row was recycled.
- Assuming the user's bar layout: position on the bar is not the slot number; ask the game which slot a key triggers.
- Saying something works when only the offline test passed. Say "not tested in the game".
