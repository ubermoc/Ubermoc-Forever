# Ubermoc Forever: research notes

What we know about building for World of Warcraft: Forever, where each fact came from, and how sure we are.
Written 2026-11-15 against Forever build **1.60.1.70938** (the `forever` branch of the UI source, 13 Nov 2026).
Forever is a beta-era client: recheck anything marked below after a patch.

## Tags

| Tag | Meaning |
| --- | --- |
| **[source]** | Read in Blizzard's UI code for Forever (`Gethe/wow-ui-source`, branch `forever`, build 70938). |
| **[dump]** | Present in the community API dump `forever-addon-kit/data/forever_api.json`. The function exists; it may not behave like Retail. |
| **[ubermoc-ui]** | Carried over from Ubermoc UI, which runs it on real controllers. Not checked against Blizzard's source. |
| **[community]** | Reported by someone else (ForeverPlusPlus `docs/forever-api.md`, forever-addon-kit). Not checked by us. |
| **[offline]** | Checked by `tools/smoke_test.py` against a stub game. Proves the logic and load order, not the game. |
| **Unverified** | Plausible, not confirmed. Check in the game. |

## The client

- Interface `16001`, product `wowf`, folder `_forever_`, internal name Camelot. **[community]**; the Updater in this account relies on the same values.
- A plain `UbermocForever.toc` with `## Interface: 16001` loads. **[community]** (tested in game by ForeverPlusPlus)
- Detect Forever by interface number range (`16000` to `16999`) or by probing for the function you need, never by "starts with 1". **[community]**
- `/run` and `/dump` can be switched off: Blizzard's chat code checks `C_AddOns.GetScriptsDisallowedForBeta()`. **[source]** This is why the addon tests itself after login (Checks button) instead of asking you to type commands.

## Controller art and text (all the game's own)

- Every button picture is an atlas named `Gamepad_<Style>_<Button>_64` (and `_32`), set up as inline text in the globals `KEY_<PAD>_LTR`, `_SHP` and `_REV` (`Blizzard_SharedXML/SharedConstants.lua`, `SetGamepadBindingStrings`). **[source]**
  - `_LTR` = letters (Xbox), `_SHP` = shapes (PlayStation), `_REV` = reversed letters (Nintendo: the bottom button is B, the right button is A).
  - No Steam-specific set. Steam Controller and Steam Deck use the letters set; back buttons use `Gen_Paddle1` to `Gen_Paddle4`.
  - PlayStation's Back is the touchpad (`Shp_TouchpadL`), Social is Share (`Shp_Share`). Ubermoc UI's text labels call Back "Create" and Social "Touchpad"; one of them is wrong for a real PlayStation pad. **Unverified.**
- `C_Texture.GetAtlasInfo(name)` tells whether an atlas exists. **[dump]**

## Controller input

- Events: `GAME_PAD_CONNECTED`, `GAME_PAD_DISCONNECTED`, `GAME_PAD_ACTIVE_CHANGED`, `GAME_PAD_CONFIGS_CHANGED`, `GAME_PAD_POWER_CHANGED`. **[source]**
- `C_GamePad.GetAllDeviceIDs`, `GetActiveDeviceID`, `GetDeviceRawState` (`name`, `vendorID`, `productID`), `GetDeviceMappedState`, `ButtonIndexToBinding`. **[source]**
- Vendor IDs used to name a controller: Valve 10462, Sony 1356, Nintendo 1406, Microsoft 1118. **[ubermoc-ui]**
- The settings `GamePadEnable`, `GamePadEmulateShift`, `GamePadEmulateCtrl`, `GamePadEmulateAlt`, `GamePadEmulateEsc` are not named in Blizzard's Lua. `GamePadEnable` appears in the restricted environment. **[source]** The rest are carried over. **[ubermoc-ui]**
- Binding functions `SetBinding`, `GetBinding`, `GetBindingKey`, `GetBindingAction`, `GetNumBindings`, `SaveBindings`, `GetCurrentBindingSet`, `GetBindingText`, and the cursor functions `SetCursorPosition`, `GetCursorPosition`, `SetGamePadCursorControl`, `CanAutoSetGamePadCursorControl`, `IsGamePadCursorControlEnabled` all exist. **[dump]**
- `SetCursorPosition`'s units are not documented. Ubermoc UI's first jump is checked against where the cursor really landed and corrected; `Nav.lua` does the same. **[ubermoc-ui]**

## Forever has its own controller interface

- `InputUtil.IsGamepadUIEnabled()` is used across Blizzard's code, with a controller-navigation system (`Blizzard_GamepadSmartNavigation`, `Blizzard_GamepadSharedUtility`). **[source]**
- It only runs in that mode (it starts and stops with `InputUtil.RegisterGamepadInit` / `RegisterGamepadUninit`), and its functions refuse to run from insecure addon code (`EnsureIsSecure`). **[source]** So an addon cannot use it to make its own window navigable.
- With it on, the game menu drops its close button and tracks its buttons in `self.buttons`. **[source]**
- ForeverPlusPlus found that menus an addon opens can break the controller's focus in that mode. **[community]**
- Ubermoc Forever is built for the mode it is played in here: Blizzard's controller interface **off**, the game's virtual cursor on. In that mode the D-pad does nothing native in a window, so `Nav.lua` adds it: a press jumps the real cursor to the next button, A clicks for real. Not yet tested in the game. **Unverified.**

## The game menu

- `GameMenuFrameMixin:InitButtons()` builds the menu in order from a pool; Options is added as `self:AddButton(GAMEMENU_OPTIONS, ...)`. Each button gets `layoutIndex` and `topPadding`; the layout sorts by `layoutIndex`. **[source]**
- Forever's `GameMenuFrameMixin:AddButton` also appends each button to `self.buttons`. **[source]**
- `Menu.lua` hooks `InitButtons` afterwards, adds "Ubermoc Forever", and gives it `layoutIndex = Options.layoutIndex - 0.5` so it sits directly above Options. Whether the layout accepts a fractional index and keeps the spacing right is **Unverified** in the game.

## Window templates used

`ButtonFrameTemplate`, `UIPanelButtonTemplate`, `UIPanelScrollFrameTemplate`, `UIPanelCloseButton`, `BackdropTemplate` all exist in the Forever source. **[source]**
The window follows the game's own layout rules. **[source]** (`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` and `.lua`)
- `ButtonFrameTemplate` has a header band under the title, then an `Inset` frame anchored top left `4,-60` and bottom right `-6,26`. The inset is `InsetFrameTemplate`: marble background (`Interface\FrameGeneral\UI-Background-Marble`) and a nine-slice border. Content goes inside the inset, not on the frame's border.
- The 26-pixel band under the inset is the bottom bar. Its buttons are `MagicButtonTemplate`, anchored to the frame's bottom right at `-6,4`, the next one to the left of the first (`RIGHT` to `LEFT`, offset `-1`).
- The action picker is a second `InsetFrameTemplate` laid exactly over the window's inset, so it covers the list underneath with the game's own marble.
- Every line of text is set to one line (no word wrap), so a long name cannot spill into the row below.
 The addon builds the window inside a `pcall` and falls back to the game's dialog textures if the window template is missing.

## Reference material

Fetch it all into Downloads with `bash tools/setup-research.sh`.

| Folder | What it is |
| --- | --- |
| `blizzard-ui-source-forever` | Blizzard's UI code for Forever. Look here first. |
| `forever-addon-kit` | `data/forever_api.json` (every function, frame and namespace), porting notes. |
| `ForeverPlusPlus` | A shipped Forever addon; `docs/forever-api.md` has sourced, dated findings. |
| `Atraeau-WoW-Addons` | A generated API reference and deploy tooling. |
| `wowlua-ls` | A WoW-aware Lua checker. |

## Found while re-checking (and what was done)

- **Combat and taken buttons (fixed).** The window takes the D-pad, bumpers and B/X/Y with override bindings. Code like ours cannot change bindings in combat, so a fight starting with the window open would have left them taken. `Nav.lua` now puts the bindings on a secure frame with a `[combat]` state driver, which drops them the moment combat starts. Ubermoc UI does the same. **[ubermoc-ui]** Blizzard's own controller code uses the same `SetOverrideBindingClick`. **[source]**
- **Steam Deck may be detected as Xbox.** Steam Input can hand the game a virtual pad that calls itself an Xbox controller. Then the Xbox layout is chosen (triggers as Shift and Ctrl) instead of the Steam layout (R4 and R5). The options header shows the device name the game reports, and the Controller button there switches to Steam Deck / Steam Controller; Reset to default then applies that layout. **Checked in game (2026-11-15, screenshot):** a Steam Deck / Steam Controller was read as `steam`, so on that setup the Steam layout is chosen without help. Other setups may differ. Ubermoc UI has the same limit and its in-game note says to set R4 = Left Shift, R5 = Left Ctrl, L4 = F6 and L5 = Space in Steam's settings.
- **Binds are account-wide.** Ubermoc UI gives each character its own copy of the binds (`charBinds`); that is not ported yet. Applying the defaults changes the binds every character shares unless the game's character-specific binds are on, while the first-run prompt asks once per character.
- **Licence.** Detection and the default layout are ported from Ubermoc UI, which is marked All Rights Reserved by Marcos; this repository is MIT. Same author, so it is his call, but it is worth deciding on purpose.

## Exit (the game's emulated Escape)

- The game can make one controller button its Escape: the setting `GamePadEmulateEsc` holds that button's name (`PADFORWARD`, ...) or `NONE`. It is not in Blizzard's Lua; it is carried over from Ubermoc UI, which reads and writes it. **[ubermoc-ui]**
- Ubermoc UI's note: the game's own Escape does close windows, clear the target and stop a cast first, and "on a controller its first steps can use up every press so the menu never opens". That is why Ubermoc UI binds Start to its own stepwise button (`CLICK UbermocMenu:LeftButton`) instead. **[ubermoc-ui]** Whether Forever behaves the same is **Unverified.**
- Our options offer **Exit (Escape)** for any button on the base layer: it sets `GamePadEmulateEsc` to that button and removes any bind on it. Binding something else to the button, or clearing it, sets the setting back to `NONE`. Only an unmodified press can be Escape, so Exit is not offered on the Shift / Ctrl layers.
- Our default is unchanged: Start is bound to the game's `TOGGLEGAMEMENU` and the setting is `NONE`. A row that shows `CLICK UbermocMenu:LeftButton` is Ubermoc UI's Start bind; it now reads "Game menu (Start)".
- The action list is the game's own binding categories, each closed until chosen, one open at a time. The category headers use the game's own plus / minus art (`Interface\Buttons\UI-PlusButton-Up`, `UI-MinusButton-Up`, used by its quest log and group finder). **[source]**

## Confirmed in the game

From a screenshot of the options window running in Forever (2026-11-15). **[in-game]**
- The addon loads and the window opens, built on the game's own `ButtonFrameTemplate`, with the game's list, buttons and scroll bar.
- The controller pictures come out as the game's own: X, A, B, Y, RB, LB, RT, LT and the D-pad.
- The legend shows A / B / X / Y pictures with their words.
- A Steam Controller / Steam Deck was detected as Steam.
- The paddle buttons used as Shift and Ctrl show as `P1` and `P3` (the game's `Gen_Paddle1` / `Gen_Paddle3` pictures), not as R4 and R5.
- The header text ran into the controller button; fixed by anchoring it to stop before the button.

## Still to check in the game

1. Whether every row of the Checks list passes on Forever.
2. Whether the "Ubermoc Forever" button lands directly above Options with correct spacing.
2b. Whether the category list (closed, one open at a time) and the Exit option look and work right, and what Exit does in Forever.
3. Whether the D-pad jump puts the cursor on the right button (the units are calibrated on the first jump).
4. Whether the PlayStation Back and Social buttons are labelled correctly.
5. Whether the `GamePad*` settings behave as in Midnight (Shift and Ctrl on the triggers, Start as the game menu).
