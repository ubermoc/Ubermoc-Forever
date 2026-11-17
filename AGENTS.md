# Ubermoc Forever: notes for coding agents

Read this first, then `docs/LUA-WOW-GUIDE.md` (Lua and game knowledge, taint rules, where to look things up, working method; essential for a small model), then `HANDOFF.md` (history, older and partly out of date) and `docs/RESEARCH*.md` (sourced facts).
The code is the truth; where a note here disagrees with it, trust the code and fix the note.

## What this is
A controller-first addon for **WoW: Forever** (game type "camelot", Interface 16001) for Steam Deck / Steam Controller
(also PS5, Xbox, Switch). Author: Marcos (GitHub `ubermoc`). Rules from the user: only Blizzard's own art and
templates, one feature at a time, research with sources first, short answers, be honest about what is untested.
The author's other addon, UbermocUI (repo `ubermoc/Ubermoc-UI`), is checked out next to this repo at `~/Downloads/Ubermoc/Ubermoc-UI` (reference for how he builds things; its own `CLAUDE.md` has its rules).
Repo `ubermoc/Ubermoc-Forever`, working branch `claude/affectionate-cray-lhlr0j`, releases are cut from `main`.

## Current state (version in `UbermocForever/UbermocForever.toc`, history in `CHANGELOG.txt`)
Built (through 1.3.58: interact on a hostile or non-interactable target opens its unit menu `TargetMenu.lua` (secure togglemenu button, `[@target,harm,nodead]` state driver; `/ubf targetmenu off`; untested); 1.3.57: Chat page "Fade by itself" per chat part (`F.implicit`, `Chat.PARTS`); 1.3.55: a third options page, Chat (`ChatPage.lua`), holds all chat settings; chat parts (`F.CHAT`) are no longer on the Fading page; 1.3.54: chat lines fade by themselves `Chat.lua` (on by default, 5 s then 3 s, from Ubermoc UI; options row 3), and `F.reveal`/`F.hold` in `Fade.lua` show a faded chat window on a new line and while the edit box is in use; 1.3.52: cinematic NPC camera `Cinematic.lua` with black bars, dark edges, nameplates and the rest of the screen hidden; A/B pictures on quest buttons and a single quest opening by itself `DialogButtons.lua`; the aim dot for ground spells `Aim.lua` (release to cast was built and removed in 1.3.40, inconsistent); the Fading page `Fade.lua` + `FadePage.lua` (about 110 elements, three situations, mouse-over opacity, Copy/Paste/Apply to the list); the equipment flyout from a gear slot; legends that fit their room; user-confirmed in the game, everything through 1.3.57 (2026-11-17, "it's all tested": the whole Chat page, lines fading, reveal on message, edit box and every chat part fading by itself, per-part opacity), cinematic, fading, the aim dot, quest flow; the rest untested (older items below). Older: 1.3.17 adds binding a spell by pressing the button combination (G.placeKey, G.bindToFree, key capture frame, Replace/Keep question), the highlight on action bars is placed by screen position and no tooltip is raised on bars (taint), 1.3.6 on top of the list below: right stick scrolls, X takes mail, glow highlight, armor kits and scopes in the Y menu; `/ubf scan` is an author tool, data notes in `docs/ITEM-USE-SCAN.md`): controller detection, four-layer default binds, options window and action picker, Start button (steps like Esc),
game-menu entry, and window navigation (`GameNav.lua`), the Y item menu (`ItemMenu.lua`), the legend (`Legend.lua`).

Window navigation: a drawn gold highlight moves with the D-pad; A = left click, X = right click, B = close button of the
window the highlight is in (then jumps to the next open window); bumpers = tabs/pages; triggers = vertical side tabs, else
scroll; Y = item menu. Quest/gossip windows start on the first option or Accept/Continue/Complete, B declines; trainers:
A selects a skill, X trains. Windows stay open in combat and the buttons go back to the player's own binds.

**Confirmed in the game by the user:** navigation, tabs, scroll, mailbox open letter, drop-downs, legend placement, item
menu side, Y menu on bags, poisons being class 0 subclass 8.
**Confirmed in the game by the user (2026-11-16, through 1.3.6):** everything above plus the vendor Sell entry, quest/gossip start and B decline, trainer X, spell binding, items on weapons and armor, right-stick scrolling, highlight-driven scrolling, X taking mail, the glow highlight. Anything not listed was not reported on: ask.

## How the code is organised
TOC load order: `Core, Layouts, Detect, Binds, Start, Legend, Nav, GameNav, ItemMenu, Scan, Cinematic, DialogButtons, Aim, Chat, Fade, FadePage, ChatPage, Prompt, Options, Menu` (the `.toc` is the truth).
- `Nav.lua`: `Nav.Push(map, secure)` takes the controller buttons with `SetOverrideBindingClick` on a
  `SecureHandlerStateTemplate` owner; a `[combat]` state driver clears the bindings. `secure` maps key to
  `{buttonName, mouseButton}`. Code cannot rebind in combat.
- `GameNav.lua`: finds windows (`G.windows`: `GetUIPanel`, `UIPanelWindows`, `UIChildWindows`, `UISpecialFrames`, bags,
  StaticPopup1-4 as modal, open drop-downs via `Menu.GetManager()` and `DropDownList1-3`), scans for buttons, draws the
  highlight, and owns three secure buttons: `UbermocForeverGameClick` (A), `UbermocForeverGameRClick` (X),
  `UbermocForeverGameBack` (B). Their `clickbutton` target is set whenever the highlight moves (`setTargets`). Pure
  helpers (`G.pick`, `G.nearest`, `G.inside`, `G.dialogStart`, `G.trainButton`) are testable offline.
- `ItemMenu.lua`: the Y menu. Entries are secure buttons: `type="item"`, or `type="macro"` with `/use bag slot`,
  `/cast <spell>`, `/click FrameName RightButton`. Max 8 entries. Only weapon slots 16 and 17 are offered (never ranged).
- `Legend.lua`, `Options.lua`, `Menu.lua`, `Start.lua`: see `HANDOFF.md` section 2.
- Debug commands in game: `/ubf check`, `/ubf tabs` (tab groups found), `/ubf item` (what the game says about the
  highlighted item), `/ubf nav on|off`. `/run` and `/dump` are blocked in Forever; never ask the user to type scripts.

## Things learned that are easy to get wrong
- **Taint / secure rules:** protected actions (clicking, `/use`, targeting) must run from a secure button, not from our
  Lua. A right click on a StaticPopup button asserts in `GameDialog.lua`, so X has no target in popups, menus and
  place mode. Close windows through `securecallfunction`.
- **Buttons with no `OnClick`** (map filter drop-down, `DropdownButtonMixin`) open on mouse DOWN. A forwarded click does
  not send it, so `GameNav` runs `OnMouseDown`/`OnMouseUp` and falls back to `SetMenuOpen`.
- **Side tabs** (`LargeSideTabButtonTemplate`) are plain Frames with `SelectedTexture` and `TabGlow`, no `Click`. They act
  on `OnMouseUp`. Tab groups also come from `TabSystem`, `Tabs` arrays, `rightProfessionTabs`, `PanelTemplates`.
- **`UIChildWindows` must be scanned** or windows like the open letter are skipped. A window that just opened takes the
  highlight.
- **Using an item at a vendor equips it.** Selling is the right-click on the bag item button (`/click <name> RightButton`),
  else pick up then `PickupMerchantItem(0)`.
- **Item classes:** poisons are class 0 subclass 8, so consumables are told apart by a "Use:" tooltip line mentioning a
  weapon (`C_TooltipInfo.GetItemByID`). Check with `/ubf item` before trusting a class number from memory.
- **Spell binding:** `C_SpellBook.PickupSpellBookItem(slot, bank)` then `C_ActionBar.PutActionInSlot(slot)`.
- **Hardcoded names are unverified until seen in the game.** `QuestFrameAcceptButton`, `ClassTrainerFrame.TrainButton`
  etc. come from Blizzard's source (`Gethe/wow-ui-source`, branch `forever`, see `tools/setup-research.sh`); use
  `/ubf tabs` and `/ubf item` style reports to confirm before building on them.
- Ask the user which control they mean when they say "pull tab" or similar; two guesses were wrong before.

## Workflow
1. Research the Blizzard source first; write sourced notes into `docs/RESEARCH-NAVIGATION.md`.
2. Change the code, add a case to `tools/smoke_test.py`, run it:
   `python3 tools/smoke_test.py` (needs `lupa`, e.g. in a venv; `tools/setup-research.sh` can make one). It must end with
   `ALL TESTS PASSED`. The test stubs the game: mocks must be plain tables where `GetParent` etc. matter.
3. **Run `bash tools/install.sh` after every change** so the user's game has it (then `/reload` in game).
4. Bump `## Version` in the `.toc`, add a `CHANGELOG.txt` entry on top (short "Added:/Fixed:" lines), update the version
   note at the top of `HANDOFF.md`, and keep `README.md` and `docs/DESCRIPTION.md` ("What it does now") in step.
5. Commit and push to the branch and to `main`. Commit identity in this repo: `Claude <noreply@anthropic.com>`
   (set with `git -c user.name=... -c user.email=...`; there is no global identity).

## Releasing (only when the user says to; it publishes)
- **GitHub:** zip whose top folder is `UbermocForever/`, named `UbermocForever-vX.Y.Z-forever.zip`
  (no `zip` binary here: use `python3 -c "import shutil; shutil.make_archive(...)"`), then
  `gh release create vX.Y.Z <zip> --title "Version X.Y.Z" --target main --latest --notes "..."`. The Ubermoc Warcraft Mod
  Updater installs from the latest non-prerelease release.
- **CurseForge** (project id 1781086, Forever flavour, game version 1.60.1): upload page
  `https://authors.curseforge.com/#/projects/1781086/files/create`. The file picker is native and cannot be driven, and
  `file_upload` only sees the session's folders. What worked: serve the zip from a throwaway local server with
  `Access-Control-Allow-Origin: *` (`python3 -m http.server` subclass on 127.0.0.1:8765), then in the page via JS:
  fetch it into a `File`, override `HTMLInputElement.prototype.click` to capture the file input the "Choose File" button
  creates, set `input.files` from a `DataTransfer`, dispatch `change`. The form copies game version and release type from
  the last file. Set the changelog with `tinymce` (`ed.setContent`, `ed.fire('change')`), press Add File. New files show
  "Uploading" then need approval (hours). Stop the local server afterwards. The tab can freeze while the page processes;
  wait and use `get_page_text` instead of screenshots.
- **CurseForge description:** `https://authors.curseforge.com/#/projects/1781086/description`, a tinymce editor: edit
  with `getContent`/`setContent`, then press Save and re-check the saved content after reloading. The public page can be
  cached for a while.
- The new feature also goes into the description (`docs/DESCRIPTION.md` is the source text).

## The user
Marcos tests fast on a Steam Deck and reports from the game, sometimes with phone photos or pasted errors. Believe a
bug report and reproduce it. He is exact about how buttons should behave; do not change stated behaviour without asking.
Give short answers, one fenced command per block, fish shell. Controller buttons: A=pad1, B=pad2, X=pad3, Y=pad4.
