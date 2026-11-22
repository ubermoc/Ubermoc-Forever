# Ubermoc Forever: notes for coding agents

Read this first, then `docs/LUA-WOW-GUIDE.md` (Lua and game knowledge, taint rules, where to look things up, working method; essential for a small model), then `HANDOFF.md` (history, older and partly out of date) and `docs/RESEARCH*.md` (sourced facts).
The code is the truth; where a note here disagrees with it, trust the code and fix the note.

**Start here if you are the local model: read `docs/LOCAL-MODEL-NOTES.md` first (short), then this file.**

## Where things live (the layout under ~/Downloads; keep it this way)
- `Projects/` holds only projects, each in its own folder named after it: `Ubermoc-Forever` (this repo, branch `main`, never edited directly), `Ubermoc-UI`, `Ubermoc-Warcraft-Mod-Updater`, `Jobs`, `Jobfit`.
- Each project folder holds its own `Project Support/`, named "<project> - <what it is>": `~/Downloads/Projects/Ubermoc-Forever/Project Support/Ubermoc-Forever - Worker Copies` (one folder per task: your work happens there) and `~/Downloads/Projects/Ubermoc-Forever/Project Support/Ubermoc-Forever - WoW Research and Tools` (Blizzard's UI source, the API data, and the Python with `lupa` that runs the offline test; made by `tools/setup-research.sh`).
- `~/Downloads/Local AI/Harness/` holds the working rules and the proof tool (`Ubermoc-Harness`). `~/Downloads/Local AI/Strata/` (the local model, 67 GB) sits under `Local AI` in its own folder, by the user's choice.
- `Installers and Archives/` holds downloaded installers and old zips. `Backups/` holds the backup sets (see its README).
- **This layout is the user's standard and always applies.** Never put loose files or tools at the top of Downloads or inside a project folder. New project: `Projects/<Name>`, its tools: `Projects/<Name>/Project Support/<Name> - <what>`. After any move or addition, update every reference (scripts, docs, services) and run `bash "$HOME/Downloads/Local AI/Harness/Config Backups/make-backup.sh"`. Map: `~/Downloads/README - folder map.md`.
- Scripts find these through `UBF_RESEARCH` (research folder) and `UBF_DOWNLOADS`; the defaults are the folders above.

## What this is
A controller-first addon for **WoW: Forever** (game type "camelot", Interface 16001) for Steam Deck / Steam Controller
(also PS5, Xbox, Switch). Author: Marcos (GitHub `ubermoc`). Rules from the user: only Blizzard's own art and
templates, one feature at a time, research with sources first, short answers, be honest about what is untested.
The author's other addon, UbermocUI (repo `ubermoc/Ubermoc-UI`), is checked out next to this repo at `~/Downloads/Projects/Ubermoc-UI` (reference for how he builds things; its own `Ubermoc.md` has its rules).
Repo `ubermoc/Ubermoc-Forever`. `main` is the single source of truth and the only thing released. Every worker (Ubermoc, the local model) works on a short-lived branch cut from the latest `main` in its own worktree and brings it back to `main` as soon as it is finished (see "How work gets to main").

## Confirmed in the game by the user (2026-11-18: everything through 1.3.129; 2026-11-17: 22 items through 1.3.103)
The gamepad layout through 1.3.93 (rows, art hidden, glyphs, cooldowns, range hue, Other binds, Bars page), the question windows (move bars, switched-off bar), the Fading page changes, the auction house Y entries (Sell at auction, Create auction), the Select + modifier default binds, the fresh start. Later the same day he confirmed 1.3.94 (icon slots for binds to another layer's button, L3/R3), 1.3.95 (XP bar parts removed) and 1.3.96 (end caps option removed): everything through 1.3.103 is tested. Released as 1.3.103 on 2026-11-17 (GitHub and CurseForge, description updated); 1.3.97 to 1.3.103 were released with offline tests only. 1.3.111 released on 2026-11-18 on GitHub and CurseForge (uploaded, waiting for approval; description updated with the Quality of life page, fast loot and the vendor features); 1.3.104 to 1.3.111 offline tests only.

## Current state (version in `Ubermoc-Forever/Ubermoc-Forever.toc`, history in `CHANGELOG.txt`)
**As of 2026-11-21 (1.3.177, released): read the top section of `HANDOFF.md`, "WHERE THINGS STAND", first. It lists what exists, what is verified in the game, what was learned, and the open work in order. The paragraphs below are older history.** Saved settings from the game can be read with `python3 tools/read_saved.py [part]` (after a `/reload`). Never put the name of an AI tool or model into files or commits.
Built (through 1.3.76: gamepad layout face button pictures black and white (option colour), option to keep the end caps hugging the row (`B.updateCaps`); gamepad layout cooldown edge + red out-of-range overlay + bound-button pictures over the top edge + micro menu/bags/XP bar default places while at the game's default position (`GamepadBar.lua` PART_FRAMES, SetPointBase); the gamepad layout `GamepadBar.lua` + `BarsPage.lua` (fourth options page, off by default, untested in the game; notes `docs/RESEARCH-GAMEPAD-BAR.md`): bound-button pictures on the buttons, forced-hidden art (`F.forced`), own fading for the bar/XP/micro/bags, Move bars opens Edit Mode (fading suspended while it is open); 1.3.72: our own marker menu `MarkerMenu.lua` (built by the local model, user-confirmed in the game 1.3.71) replaces the game's marker submenu (it was built tainted); 1.3.70: secret values from the game are guarded (`Fade.lua plain`); 1.3.69: submenu opening is throttled (a flood of warnings on an enemy player); 1.3.67: a marker in the target menu goes through a secure `raidtarget` button of ours (`G.markerOf`), the menu entry click was refused as tainted; 1.3.66: A on the game's menu entries writes `clickbutton` inside `securecallfunction` (a frame stored by our code taints the click; the frame-reference idea of 1.3.65 failed, it stores a handle); 1.3.64: no tooltip (OnEnter) step on the game's menu entries, it tainted the menu and refused a marker; 1.3.63: the submenu is opened through securecallfunction (else its entries are refused as tainted); 1.3.62: A opens a menu entry's submenu (`G.opensSubmenu`, `G.findSubmenu`, `G.submenu`); 1.3.61: `TargetMenu.lua` points the interact key at `TargetFrame` with a right click (fallback: hidden togglemenu button); follows the game's interact order (soft interact target first), `/ubf targetmenu` reports; the user does NOT run Ubermoc UI and Ubermoc Forever together, never assume it; 1.3.58: interact on a hostile or non-interactable target opens its unit menu `TargetMenu.lua` (secure togglemenu button, `[@target,harm,nodead]` state driver; `/ubf targetmenu off`; untested); 1.3.57: Chat page "Fade by itself" per chat part (`F.implicit`, `Chat.PARTS`); 1.3.55: a third options page, Chat (`ChatPage.lua`), holds all chat settings; chat parts (`F.CHAT`) are no longer on the Fading page; 1.3.54: chat lines fade by themselves `Chat.lua` (on by default, 5 s then 3 s, from Ubermoc UI; options row 3), and `F.reveal`/`F.hold` in `Fade.lua` show a faded chat window on a new line and while the edit box is in use; 1.3.52: cinematic NPC camera `Cinematic.lua` with black bars, dark edges, nameplates and the rest of the screen hidden; A/B pictures on quest buttons and a single quest opening by itself `DialogButtons.lua`; the aim dot for ground spells `Aim.lua` (release to cast was built and removed in 1.3.40, inconsistent); the Fading page `Fade.lua` + `FadePage.lua` (about 110 elements, three situations, mouse-over opacity, Copy/Paste/Apply to the list); the equipment flyout from a gear slot; legends that fit their room; user-confirmed in the game, everything through 1.3.67 (2026-11-17: the interact key opens the target's menu, submenus open, markers can be set; and, "it's all tested", everything through 1.3.57: "it's all tested": the whole Chat page, lines fading, reveal on message, edit box and every chat part fading by itself, per-part opacity), cinematic, fading, the aim dot, quest flow; the rest untested (older items below). Older: 1.3.17 adds binding a spell by pressing the button combination (G.placeKey, G.bindToFree, key capture frame, Replace/Keep question), the highlight on action bars is placed by screen position and no tooltip is raised on bars (taint), 1.3.6 on top of the list below: right stick scrolls, X takes mail, glow highlight, armor kits and scopes in the Y menu; `/ubf scan` is an author tool, data notes in `docs/ITEM-USE-SCAN.md`): controller detection, four-layer default binds, options window and action picker, Start button (steps like Esc),
game-menu entry, and window navigation (`GameNav.lua`), the Y item menu (`ItemMenu.lua`), the legend (`Legend.lua`).

Window navigation: a drawn gold highlight moves with the D-pad; A = left click, X = right click, B = close button of the
window the highlight is in (then jumps to the next open window); bumpers = tabs/pages; triggers = vertical side tabs, else
scroll; Y = item menu. Quest/gossip windows start on the first option or Accept/Continue/Complete, B declines; trainers:
A selects a skill, X trains. Windows stay open in combat and the buttons go back to the player's own binds.

**Confirmed in the game by the user:** navigation, tabs, scroll, mailbox open letter, drop-downs, legend placement, item
menu side, Y menu on bags, poisons being class 0 subclass 8.
**Confirmed in the game by the user (2026-11-16, through 1.3.6):** everything above plus the vendor Sell entry, quest/gossip start and B decline, trainer X, spell binding, items on weapons and armor, right-stick scrolling, highlight-driven scrolling, X taking mail, the glow highlight. Anything not listed was not reported on: ask.

## How the code is organised
TOC load order: `Core, Layouts, Detect, Binds, Start, Legend, Describe, Nav, GameNav, TargetCancel, MarkerMenu, TargetMenu, Applied, ApplyConfirm, ItemMenu, Scan, NavScans, Trail, Diag, FlightPaths, Cinematic, DialogButtons, Aim, Loot, Vendor, Nameplates, NameHealth, PlateQuest, PlateLevel, PlateRange, QuestArrow, Chat, ChatEdit, Fade, FadePage, ChatPage, GamepadBar, BarsPage, QolPage, Prompt, Options, Menu` (the `.toc` is the truth). Newer parts: `Trail.lua` (learned trail, rides, entrances), `QuestArrow.lua` (the arrow and Breadcrumbs), `FlightPaths.lua` (map pins), `NavScans.lua` (author scans), `Diag.lua` (combat/conversation timeline).
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
  highlighted item), `/ubf nav on|off`; navigation scans, one at a time, saved into the saved settings: `/ubf docks`, `/ubf taxi`, `/ubf maps`, `/ubf entrances`, `/ubf scans [stop]`; `/ubf learned` (what the trail, ride and entrance learning knows); `/ubf combat` (the timeline around the end of a fight or a talk, for the stealth delay); `/ubf flightpaths [show]` (what the game says about flight points; show brings hidden pins back); `/ubf arrow`, `/ubf errors`, `/ubf loads`. `/run` and `/dump` are blocked in Forever; never ask the user to type scripts.

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
- **Taint lessons are in `docs/LUA-WOW-GUIDE.md` sections 3 and 8** (frame stored in a secure attribute, menu entries, the taint log procedure, never assume which addons run). Read them before touching secure buttons or menus.
- Ask the user which control they mean when they say "pull tab" or similar; two guesses were wrong before.

## Workflow
1. Research the Blizzard source first; write sourced notes into `docs/RESEARCH-NAVIGATION.md`.
2. Change the code, add a case to `tools/smoke_test.py`, run it:
   `python3 tools/smoke_test.py` (needs `lupa`, e.g. in a venv; `tools/setup-research.sh` can make one). It must end with
   `ALL TESTS PASSED`. The test stubs the game: mocks must be plain tables where `GetParent` etc. matter.
   Also run `python3 tools/check_lua.py Ubermoc-Forever/<file>.lua [--risky]`: the game runs Lua 5.1 and the test runs 5.5, so only this catches 5.4-only syntax, an accidental global, or a typo'd game function. It must end with `PASSED`.
3. **When the work is finished and committed, run `bash tools/finish.sh`** in your own worker folder, without being asked.
   It brings your branch up to date with `main`, renumbers your version if `main` moved on, runs the offline test and the
   Lua checker, and installs the addon into the game from your folder so the user can test it (`/reload` in game). That is
   the one standing permission; do not install any other way and do not install for a report-only request
   ("look into", "report back first"). The hand-off summary also says how long the task took (working rule 5).
4. Bump `## Version` in the `.toc`, add a `CHANGELOG.txt` entry on top (short "Added:/Fixed:" lines), update the version
   note at the top of `HANDOFF.md`, and keep `README.md` and `docs/DESCRIPTION.md` ("What it does now") in step.
5. Commit on YOUR OWN branch only. Commit identity in this repo: `Ubermoc <ubermoc@users.noreply.github.com>`
   (set with `git -c user.name=... -c user.email=...`; there is no global identity). Stage files by name, never `git add -A`.
   A worker never merges into `main`, pushes, or releases on its own. A report-only request gets a report: no commits.

## How work gets to main (the same for Ubermoc and the local model)
In words: **commit** = save your work in git on your own branch; **merge + push** (`ship.sh`) = put it into `main` and upload `main` to GitHub; **release** = publish that version for everyone who uses the mod. Finished work is ALWAYS installed in the user's game first (`finish.sh` does it): he tests at the end.
1. Start: `bash tools/work-start.sh <name> [ubermoc|local]` makes your own worktree and branch cut from the latest `main`
   (`~/Downloads/Projects/Ubermoc-Forever/Project Support/Ubermoc-Forever - Worker Copies/<who>-<name>`, branch `ubermoc/<name>` or `local-model/<name>`). Never two workers in one folder,
   never edit the main folder. One feature per branch.
2. Start AND end every session with `bash tools/status.sh` (one screen: version, pushed or not, released or not, unmerged branches,
   uncommitted work, local model up). Check the toolbox once: `bash tools/doctor.sh` says what is missing and how to fix it.
3. Finish: commit, then `bash tools/finish.sh` (sync with main + renumber, tests, checker, install for testing). It does not merge.
4. Ship (the user, or Ubermoc when the user says "ship it"/"merge it"): in the main folder `bash tools/ship.sh <branch>`
   merges with the tests as a gate, and pushes `main`. If a merge ever conflicts outside the version, changelog and
   hand-off notes, nothing is changed: ask Ubermoc to resolve it.
5. Release (only when the user says to; it publishes): `bash tools/release.sh vX.Y.Z` (GitHub). CurseForge is a manual step below.
6. Version numbers belong to `main`: the next free number is whatever `main` has plus one. Two branches open at the same time
   both get renumbered by `tools/sync-main.sh` when the second one finishes, so a clash never reaches `main`.
7. Never leave a finished branch unmerged: if the user does not say what to do with it, say in your final message that it
   waits for `bash tools/ship.sh <branch>`.
- Claude Code and the local model read this same file (`Ubermoc.md` points here); the local model also reads `docs/LOCAL-MODEL-NOTES.md`.

## Releasing (only when the user says to; it publishes)
- **GitHub:** `bash tools/release.sh vX.Y.Z` does it (zip, notes from CHANGELOG, `gh release create`). By hand: zip whose top folder is `Ubermoc-Forever/`, named `Ubermoc-Forever-vX.Y.Z-forever.zip`
  (no `zip` binary here: use `python3 -c "import shutil; shutil.make_archive(...)"`), then
  `gh release create vX.Y.Z <zip> --title "Version X.Y.Z" --target main --latest --notes "..."`. The Ubermoc Warcraft Mod
  Updater installs from the latest non-prerelease release.
- **The release browser (use it for every CurseForge step).** Chrome 136+ ignores the debugging port on the everyday profile, so the browser tools use their own Chrome: `Project Support/Ubermoc-Forever - Release Browser/release-browser` (`start [url]`, `status`, `stop`), its own profile folder beside it, port 9222 on 127.0.0.1. The Pi browser tools start it and attach to it by themselves (local patch in `~/.pi/agent/extensions/pi-browser/index.ts`, switched on by `~/.pi/agent/pi-browser-release.json`; `/browser connect` is not needed). The CurseForge login lives only in that profile: if a page shows the login screen, tell the user to log in there once; never try to log in yourself or copy cookies from the everyday Chrome. Details: `docs/LOCAL-MODEL-NOTES.md`, "The release browser".
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
- The new feature also goes into the description (`docs/DESCRIPTION.md` is the source text). The screenshots section of the CurseForge description is `docs/screenshots.html` (images from `docs/images/` through raw.githubusercontent.com URLs); insert it before the "What it does now" heading of the converted description. The originals are in the author's Steam screenshots folder (`~/.steam/steam/userdata/<id>/760/remote/<game>/screenshots/`), the file names are the labels. Newer ones (from 2026-11-17 afternoon) are in `~/.steam/steam/userdata/5623127/760/remote/6078525/screenshots/`, named by time only: look at each picture to label it. Seven of those were added on 2026-11-18 (controller-mailbox, item-menu-poison, item-menu-armor-kit, equipment-flyout, spellbook-bind, in-combat, out-of-combat-tooltip); window shots are cropped to a quarter of the 4K frame, everything is saved at 1600x900.

## The user
Marcos tests fast on a Steam Deck and reports from the game, sometimes with phone photos or pasted errors. Believe a
bug report and reproduce it. He is exact about how buttons should behave; do not change stated behaviour without asking.
Give short answers, one fenced command per block, fish shell. Controller buttons: A=pad1, B=pad2, X=pad3, Y=pad4.
