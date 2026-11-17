# Hand-off: Ubermoc Forever

Written 2026-11-15 at the end of the first working session, updated at the end of its last stretch. Read this whole
file before doing anything. It says what the project is, what the user wants, what is built, what is proven and what
is not, and what to do next.

**Newer notes are in `AGENTS.md` (current state, release routine for GitHub and CurseForge, gotchas). Where this file disagrees with it, `AGENTS.md` wins.**

**Where it stands (read this first):** addon version **1.3.57** (Chat page: every chat part has Fade by itself, hidden until the chat is used; the user confirmed 1.3.53 to 1.3.57 work in the game on 2026-11-17; 1.3.56: edit box only; 1.3.55: Chat page, the third options page: chat settings and per-part opacity live there, not on the Fading page, tabs never auto-open; untested in the game; 1.3.54: a faded chat window and the edit box appear on new lines and while typing, then wait and fade, `F.reveal`/`F.hold`; untested in the game; 1.3.53: chat lines fade by themselves, `Chat.lua`, new options row, untested in the game; 1.3.52: universal mouse-over opacity on the Fading page; 1.3.51: Fading expanded to about 110 elements with parts, scrolling list, copy/paste/apply, /ubf fade; untested in the game; 1.3.48: A on a gear slot opens the equipment flyout, GameNav.lua flyoutOpener, untested; 1.3.41: Fade.lua + FadePage.lua: fading of interface elements by situation, a second page in the options window, untested in the game, notes docs/RESEARCH-FADE.md; 1.3.27: release to cast for ground spells was built (1.3.27 to 1.3.32) and removed in 1.3.40 because it worked inconsistently; 1.3.25: Aim.lua: white aim dot for ground spells + aim distance, untested; see docs/RESEARCH-GROUND-SPELLS.md; 1.3.21: DialogButtons.lua draws quest/gossip buttons as controller strips, untested; 1.3.18: cinematic camera while talking to an NPC, `Cinematic.lua`, notes in docs/RESEARCH-CINEMATIC.md; not yet tested in the game; /ubf cinema on|off; 1.3.17: spell binding is by pressing the button combination: it goes to the slot that combination triggers, or a free combination gets the first empty slot on a visible bar and a bind, or the game asks Replace/Keep it; nothing of ours is anchored to action bars and no tooltip runs on them because that tainted the bars; user-confirmed in the game 2026-11-16; 1.3.6: the right stick scrolls lists and text (stick API as Ubermoc UI uses it), highlight-driven scrolling moves the list minimally and scrolls at the edge, X takes everything in a mail (AutoLootMailItem), the highlight is a glow, the Y menu reads where an item goes from its use text (M.targets: armor kits, scopes), /ubf scan author tool; all confirmed in the game by the user on 2026-11-16; 1.3.5: quest and gossip windows start on their first option or the Accept/Continue/Complete button (G.dialogStart), B is Decline, X trains in ClassTrainerFrame (G.trainButton); unconfirmed in the game; 1.3.4: the vendor Sell entry right-clicks the item button (or picks it up onto the vendor) because using the item equipped it; 1.3.3: X is its own secure button (UbermocForeverGameRClick) and has no target in question windows, menus and place mode: a right click on StaticPopup buttons asserted in GameDialog.lua; 1.3.2: nothing is offered for ranged weapons (slot 18); 1.3.1: poisons confirmed in game as class 0 subclass 8 via /ubf item, so consumables are told apart by a Use: line that mentions a weapon (tooltip data); 1.3.0: Y menu rewritten (ItemMenu.lua): items used on weapons (rule in usedOnItems, unconfirmed in game: /ubf item prints class/subclass), Disenchant/Prospect/Mill, worn-item menu lists bag items usable on it, any button with GetItemLocation; tooltip shown beside the highlight on the side with room; 1.2.9: the Menu: Left/Right option and /ubf menu command are gone; the item menu always picks the side with room; 1.2.8: the item menu picks a side with room: the chosen side when it fits, else the other, always clamped to the screen; 1.2.7: buttons with no OnClick (the map filter drop-down: WorldMapTrackingOptionsButtonTemplate, a DropdownButton) get their OnMouseDown/OnMouseUp run on A/X, as ConsolePort GetEmuClick does; errors go to /ubf check; 1.2.6: drop-down buttons (DropdownButtonMixin opens on mouse DOWN) are toggled with SetMenuOpen on A/X; open menus (Menu.GetManager, DropDownList1-3) are modal, the highlight jumps in, B closes them, highlight returns to the button; 1.2.5: the legend bar wraps onto more rows so it is never wider than the window it sits under; 1.2.4: windows list now includes UIPanelWindows and UIChildWindows (the open letter, guild pop-ups) and a window that just opened takes the highlight; 1.2.3: side tabs are plain Frames from LargeSideTabButtonTemplate (no Click): found by SelectedTexture+TabGlow+OnMouseUp, pressed by running OnMouseUp; /ubf tabs lists what was found; 1.2.2: triggers step the vertical side tabs (profession tabs etc.) when a window has them, else scroll; 1.2.1: item menu side option: "Menu: Left/Right" button on the options window and /ubf menu left|right; the highlight now jumps into the item menu so B closes it; 1.2.0: B closes the window the highlight is in then jumps to the next open one; bumpers step the tab group nearest the highlight (TabSystem, Tabs arrays, rightProfessionTabs, PanelTemplates); legend sits under that window; Y menu also on worn items (Use, Pick up) and spells ("Bind to action bar": picks the spell up, highlight moves over the action bars, A places it with C_ActionBar.PutActionInSlot, B cancels); all untested in the game. 1.1.2: a legend bar at the bottom of the screen lists what each button does over the game windows, Y only on bag items; 1.1.1: Y on a bag item opens `ItemMenu.lua`: Use or Sell, Pick up, Delete (asks twice), Sort bags; spells not yet. Before that 1.1.0, in use and working per the user: `GameNav.lua` moves a drawn gold highlight around the game's own windows: D-pad moves, A/X secure left/right click, B close button, bumpers tabs with wrap, triggers scroll, auto-scroll to the highlight, modal question windows; `/ubf nav off` turns it off; design in docs/RESEARCH-NAVIGATION.md sections 5 and 7; Nav.Push now takes a second table of secure keys. Also 1.0.9: windows stay open in combat, the player closes them. 1.0.7 added the combat rule: windows refuse to open in combat, buttons retaken after combat; untested in the game. Navigation research is in docs/RESEARCH-NAVIGATION.md; the user chose highlight + real clicks for the game's own windows, next feature) (numbering continues from CurseForge's 1.0.5; 0.3.x work: Start is now a stepped button ported from Ubermoc UI, `Start.lua`, bound on all four layers with the game's own Escape off; the legend has LB/RB "Prev hold"/"Next hold" and the bumpers wrap; window widened to 650. Unconfirmed in the game. Supersedes the "Start alone = Exit" notes below.), last commit `4a10dfe` on the branch below. The window,
the picker, Start = Exit and the D-pad navigation are all in. The user has been testing in the game from phone photos
and found real bugs each round; the **latest fix (0.2.1) is not yet confirmed in the game**. The first thing to do is
ask the user to update, check the version shown in the window, and report what the picker does.

- **Repo:** `ubermoc/Ubermoc-Forever` (public). **Branch:** `claude/affectionate-cray-lhlr0j`. **PR:** [#1](https://github.com/ubermoc/Ubermoc-Forever/pull/1), draft, not merged.
- **If you cannot see this file on the default branch**, it is on the branch above. Read it from there.
- The addon is `UbermocForever/`. Everything else (`tools/`, `docs/`, `README.md`) supports it.

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
  `CLAUDE.md` says so).
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
| `UbermocForever.toc` | `## Interface: 16001`, `SavedVariables: UbermocForeverDB`, load order below. |
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
5. **Release process is not set up.** The Ubermoc Warcraft Mod Updater installs from the **latest non-prerelease GitHub release** of `ubermoc/Ubermoc-Forever` with a zip whose top folder is `UbermocForever/` (see `Ubermoc-Warcraft-Mod-Updater/py_modules/ubermoc_wow/service.py`, `DEFAULT_ADDONS`). Ubermoc UI's `CLAUDE.md` has its release routine (version in the TOC, `CHANGELOG.txt`, tag `vN`, `git archive --prefix=...`, GitHub release, CurseForge). None of that exists here yet, and `gh` is not available in the cloud session. Ask before doing any release.
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
- **Git rules for the session:** develop on `claude/affectionate-cray-lhlr0j`; commit messages end with the attribution lines the session gives; keep the PR a draft; the session is subscribed to PR #1 events. Do not merge or approve. Do not put model names in commits or PR text. Ask before anything outward-facing (releases, comments, uploads).
- **Be honest about status.** Say what is proven in the game, what only passes offline, and what has not been tried.

### Running Claude on their computer in the background (set up this session, in progress)
The user wants Claude running all the time on their CachyOS handheld, including Gaming Mode, so they can work on the
repos remotely from a phone. Set up as a **systemd user service** `~/.config/systemd/user/claude-remote.service` that
runs `claude remote-control` in `~/Downloads/Ubermoc/Ubermoc-Forever`, with `UnsetEnvironment=ANTHROPIC_API_KEY`
(Remote Control needs the claude.ai login), `Nice=19`, `CPUWeight=20`, `MemoryMax=1G`, `Restart=on-failure`, plus
`loginctl enable-linger $USER`. **Status:** the service started and failed with "Workspace not trusted". The fix given:
run `claude` once in that folder, accept the trust prompt, `/exit`, then `systemctl --user restart claude-remote.service`.
**Not yet confirmed** that it now stays up. If it exits at once with no clear message it may need a terminal: fall back
to a tmux-based unit (`Type=forking`, `RemainAfterExit=yes`, `tmux new-session -d -s claude-remote ...`). Each repo
folder needs its own trust acceptance (and its own service if wanted). None of this was tested on their machine from
here; ask for `systemctl --user status claude-remote.service` and `journalctl --user -u claude-remote.service -n 30 --no-pager`.

### Lessons about working with this user
- They test fast and report from the game. When they say something doesn't work, believe them and reproduce it. Two reports that looked like user error were real bugs (the category list, the Escape row).
- They are exact about how the game should behave ("Start alone should equal Exit"). Do not change their stated defaults without asking, and ask one specific question when a rule is ambiguous.
- They want short copy-paste steps, one command per block, fish syntax. They have hit "no such file" errors from `git fetch` without `git pull`, and from running commands outside the repo folder. Say the folder and the exact commands.

## 7. First thing to say to the user in the new session

Summarise the "Where it stands" paragraph and section 3 in a few lines, say which fixes are untested in the game, and ask
them to run `git pull` and `bash tools/install.sh` (the last line should say version 0.2.1 or newer), restart the game,
then send photos of: the Esc menu, the main window (the version is in the grey text in its header line), the picker
after pressing Change, and the Checks output. Then ask whether `claude-remote.service` is running.
