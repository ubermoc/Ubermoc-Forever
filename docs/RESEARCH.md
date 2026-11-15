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
- `Menu.lua` hooks `InitButtons` afterwards, adds "Controller", and gives it `layoutIndex = Options.layoutIndex - 0.5` so it sits directly above Options. Whether the layout accepts a fractional index and keeps the spacing right is **Unverified** in the game.

## Window templates used

`ButtonFrameTemplate`, `UIPanelButtonTemplate`, `UIPanelScrollFrameTemplate`, `UIPanelCloseButton`, `BackdropTemplate` all exist in the Forever source. **[source]** The addon builds the window inside a `pcall` and falls back to the game's dialog textures if the window template is missing.

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
- **Steam Deck may be detected as Xbox.** Steam Input can hand the game a virtual pad that calls itself an Xbox controller. Then the Xbox layout is chosen (triggers as Shift and Ctrl) instead of the Steam layout (R4 and R5). The options header shows the device name the game reports, and the Controller button there switches to Steam Deck / Steam Controller; Reset to default then applies that layout. What a real Deck reports is **Unverified.** Ubermoc UI has the same limit and its in-game note says to set R4 = Left Shift, R5 = Left Ctrl, L4 = F6 and L5 = Space in Steam's settings.
- **Binds are account-wide.** Ubermoc UI gives each character its own copy of the binds (`charBinds`); that is not ported yet. Applying the defaults changes the binds every character shares unless the game's character-specific binds are on, while the first-run prompt asks once per character.
- **Licence.** Detection and the default layout are ported from Ubermoc UI, which is marked All Rights Reserved by Marcos; this repository is MIT. Same author, so it is his call, but it is worth deciding on purpose.

## Still to check in the game

1. Whether every row of the Checks list passes on Forever.
2. Whether the "Controller" button lands directly above Options with correct spacing.
3. Whether the D-pad jump puts the cursor on the right button (the units are calibrated on the first jump).
4. Whether the PlayStation Back and Social buttons are labelled correctly.
5. Whether the `GamePad*` settings behave as in Midnight (Shift and Ctrl on the triggers, Start as the game menu).
