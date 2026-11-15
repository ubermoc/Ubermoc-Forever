# Hand-off: Ubermoc Forever

Written 2026-11-15 at the end of the first working session. Read this whole file before doing anything. It says what
the project is, what the user wants, what is built, what is proven and what is not, and what to do next.

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

Defaults (same as Ubermoc UI): Steam Controller/Deck uses R4 as Shift and R5 as Ctrl; every other controller uses the
left trigger as Shift and the right trigger as Ctrl. Right bumper targets the nearest enemy, left bumper the nearest
friend. Start is the game menu, Select is the map. Interact and jump are on L4/L5 (stick clicks on pads without back
buttons).

## 3. What is proven and what is not

**Proven in the game (user photos, 2026-11-15):** the addon loads; the window opens built on the game's own frame; the
controller pictures are the game's own; a Steam Deck / Steam Controller is read as `steam` (the game reports the device
as "Steam Controller"); the action picker opens.

**Proven only offline (`tools/smoke_test.py`, stubbed game):** the files compile and load; detection and the three
picture styles; both default layouts; the first-run prompt; the picker choosing an action; the highlight walking the
whole list in order without wrapping; A, B, X, Y; the question windows taking A and B; the combat driver is registered;
the controller button label stays short. The stub **cannot** show how the game really behaves.

**Not yet seen in the game (do these first):**
1. **The "Ubermoc Forever" entry in the Esc menu.** The user has never sent a photo of it. It relies on giving the new button `layoutIndex = Options.layoutIndex - 0.5`. Unverified.
2. **The latest navigation** (commit `c5f9261` and later): D-pad highlight, A presses, B/X/Y, bumpers. The user reported three problems with the *previous* version; all three were fixed but **none confirmed**:
   - the controller button's label spilled out of the button (fixed: short names, sized to fit);
   - the face buttons fired the action bars instead of the window (fixed: A is now taken too);
   - the list jumped back to the top after about seven presses (fixed by dropping the pointer-moving code).
3. **The first-run prompt** and **applying the defaults** on a real character.
4. **The picker** after two rounds of changes: the higher draw layer with the list under it hidden, and the newest category list (closed by default, one open at a time, plus an **Exit (Escape)** option). The user asked for both; neither has been seen in the game.
5. **Release of the buttons in combat** (secure `[combat]` driver) and when the window closes.
6. The Checks list: whether every row passes on Forever. Ask the user to press Checks and paste the chat output.

## 4. Things learned the hard way (do not relearn these)

- **The game's virtual cursor does not click with A.** Its click buttons are CVars `GamePadCursorLeftClick` (default R2) and `GamePadCursorRightClick` (default R1). With A untaken, A fires `ACTIONBUTTON2`. Ubermoc UI takes A itself. Our `Nav.lua` takes A, B, X, Y, the D-pad and the bumpers with `SetOverrideBindingClick`.
- **Do not move the pointer by code.** `SetCursorPosition`'s units are undocumented; the first attempt (ported calibration) misbehaved. Nav now moves a **highlight** (`LockHighlight`) and presses with `button:Click()`.
- **Override bindings cannot be changed by addon code in combat.** The owner frame is `SecureHandlerStateTemplate` with `RegisterStateDriver(owner, "combat", "[combat] 1; 0")` and `_onstate-combat` calling `self:ClearBindings()`. Same as Ubermoc UI.
- **Forever has its own controller interface** (`InputUtil.IsGamepadUIEnabled()`, `Blizzard_GamepadSmartNavigation`). It only runs in that mode and refuses insecure callers, so addons cannot use it. The user plays with it **off**. Forever++ warns that addon-opened menus can break focus when it is on.
- **`GetBinding(i)` returns the category as the name of the header text** (`"BINDING_HEADER_MOVEMENT"`), not the text. Look it up as a global.
- **A raised frame level alone did not put the picker above the rows.** It needs `SetFrameStrata("FULLSCREEN_DIALOG")`, and the list underneath is hidden while it is open.
- **Native layout rules** (`ButtonFrameTemplate`): header band under the title; content inside `Inset` (top left `4,-60`, bottom right `-6,26`); bottom bar holds `MagicButtonTemplate` buttons (bottom right `-6,4`, next one `RIGHT` to `LEFT` offset `-1`). Every line of text is set to one line (`SetWordWrap(false)`) so nothing wraps into the next row.
- **`/run` and `/dump` are blocked** in Forever (`C_AddOns.GetScriptsDisallowedForBeta()`). Never ask the user to type scripts. Use the in-addon Checks.
- **Exit is the game's emulated Escape, not a bind.** `GamePadEmulateEsc` holds the button (or `NONE`). `UF.setExit(pad)` sets it and clears the bind; `UF.setBind` sets it back to `NONE` when something else is bound to that button. Ubermoc UI warns the game's native Escape can use up presses on a controller so the menu never opens; our default Start is still `TOGGLEGAMEMENU`. A row reading `CLICK UbermocMenu:LeftButton` is Ubermoc UI's Start bind, now shown as "Game menu (Start)".
- **`GamePadEmulateShift/Ctrl/Alt/Esc` and `GamePadEnable` are not in Blizzard's Lua.** They are carried over from Ubermoc UI, which runs them.
- **The paddle buttons used as Shift/Ctrl show as `P1` / `P3`** (the game's `Gen_Paddle1/3` pictures). They are R4/R5 on the Deck. The user has not asked to change this. Offer to add "R4"/"R5" text beside the pictures.
- **Test-stub traps:** the stub must treat lowercase field names as plain data, track Show/Hide and fire OnShow/OnHide, and provide `Click`, `GetTextWidth`, `Inset`, `CloseButton`. Add to the stub when new code needs it. When a stub-only failure appears, check whether the real game would behave differently before changing the addon.

## 5. Known gaps and the next steps, in order

1. **Get the user's in-game results** for section 3 (items 1 to 6). Ask for photos and the Checks output. Fix what they show.
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

## 7. First thing to say to the user in the new session

Summarise section 3 in a few lines, say that the three fixes from the last session are untested in the game, and ask
them to run `git pull` and `bash tools/install.sh`, restart the game, then send photos of: the Esc menu, the main
window, the picker, and the Checks output.
