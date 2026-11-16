# Research: ground-target spells, a mark, hold to aim, release to cast (2026-11-16)

Source read: `UbermocUI/Aim.lua` (507 lines, the user's own addon). Not copied.

## What UbermocUI does
- **Mark:** a frame `UbermocAimMark` (strata TOOLTIP, no mouse) with a dot or cross texture, white by default, 80 % opacity, size and
  offset adjustable. Shown while `SpellIsTargeting()` is true (the game is waiting for a ground spot) or while a ground spell's button is
  held. Placed at `CENTER` of `UIParent` horizontally and at `GetScreenHeight() * CursorCenteredYPos` vertically.
- **"Distance":** there is no yard setting. A ground spell lands where the game's centred pointer rests while the controller steers the
  camera. UbermocUI moves that pointer up or down with the game's own CVar `CursorCenteredYPos` (0.3 to 0.9 of the screen height); higher
  on screen = further from the character. Exact yards cannot be set by an addon (it depends on camera angle and terrain).
- **Pointer:** CVar `GamePadCursorForTargeting` set to `0` so the aim stays at the centred pointer instead of a stick-moved cursor
  (old value saved, restored when the option is off).
- **Hold to aim, release to cast:** the game's own "Press and Hold Casting" (`ActionButtonUseKeyHeldSpell`, `ActionButtonUseKeyDown`)
  only releases for spells with a `typerelease` action (empowered spells). So UbermocUI sets, **out of combat, on every action button
  holding a ground spell**: attribute `typerelease = "macro"` and `macrotext = "/stopspelltarget\n/cast [@cursor] <Spell Name>"`, plus
  `HookScript("PreClick")` to know the button is held. Which spells are "ground" is a list of spell IDs (Heroic Leap 6544, Blizzard 190356,
  Flamestrike 2120, Rain of Fire 5740, Death and Decay 43265, Healing Rain 73920 ...), plus any spell that starts a reticle when pressed
  (learned by checking `SpellIsTargeting()` 0.1 s after a click).
- It also writes fields on the buttons (`b.ubGround`, `b.ubWatch`).

## Risks for Ubermoc Forever
1. **Taint.** Setting attributes on Blizzard action buttons, hooking their `PreClick` and writing fields on them is exactly what caused the
   "secret value" and `MainActionBar:SetPointBase` errors earlier (see `LUA-WOW-GUIDE.md` section 3). Copying that part is the risky piece.
2. Must not run together with UbermocUI's aiming (both change the same CVars and buttons).
3. CVars changed must be saved first and restored.

## Pieces, easiest first
A. **The mark** (low risk): a white dot, shown only while `SpellIsTargeting()`, at the centred-pointer position; size, opacity, offsets adjustable.
B. **Aim height** (low risk): our setting moves `CursorCenteredYPos`; shown as "closer / further", not yards. CVars saved and restored.
C. **Hold to aim, release to cast** (the risky one): needs either UbermocUI's button attributes (taint risk), or our own secure button
   (macro `/cast [@cursor] Spell`) triggered by our own override binding on release. Needs an in-game test of what the game does when the
   key is released (`OnGamePadButtonUp` on a capture frame while `SpellIsTargeting()`), because casting at the cursor is a protected action.

## Release to cast, built in 1.3.27 (GroundCast.lua), not yet tested in the game
Blizzard_FrameXML/SecureTemplates.lua: `SecureActionButton_OnClick` runs `OnActionButtonPressAndHoldRelease` on key up when the button has
the attribute `pressAndHoldAction` (or the CVar `ActionButtonUseKeyHeldSpell` is on), and that looks up the attribute `typerelease`
for the action type. Blizzard's bar buttons have none for ground spells, so letting go does nothing. Our own secure buttons get:
`pressAndHoldAction=true`, `type=spell` + `spell=<name>` (key down starts the aim), `typerelease=macro` + `macrotext=/stopspelltarget` and
`/cast [@cursor] <name>` (key up casts). They take the key with `SetOverrideBindingClick` (out of combat), cleared when turned off.
The user's game reports `ActionButtonUseKeyHeldSpell` = 1 and `ActionButtonUseKeyDown` = 1 (`/ubf hold`; UbermocUI may have set them).

## Source check of GroundCast.lua (1.3.31), against `blizzard-ui-source-forever`
Confirmed by reading Blizzard's code (not yet by running it in the game):
- Button frames: `ActionButton<i>` for the main bar, `<BarFrameName>Button<i>` for the others (`Shared/ActionBar.lua` lines 15-30), e.g.
  `MultiBarBottomLeftButton1`. The slot is `button.action` (`Shared/ActionButton.lua` UpdateAction, ~line 545).
- Key names: `commandName = prefix.."BUTTON"..i`, prefixes `ACTION`, `MULTIACTIONBAR1..7` (`MultiActionBars.xml`). The game itself looks up a button's
  key with `GetBindingKey(bindingAction)` or `GetBindingKey("CLICK <name>:LeftButton")` (`ActionButton.lua` ~line 498): we now do both.
- `C_Spell.IsPressHoldReleaseSpell` is documented as "empower" spells only, and Blizzard sets `pressAndHoldAction` on its bar buttons from it
  (`ActionButton.lua` `UpdatePressAndHoldAction`). So ground spells get no release action from the game: the reason for GroundCast.lua.
- The game's own pressed look of a bar button is `C_ActionBar.IsCurrentAction(action)` (`ActionButton.lua` line 717). The global `IsCurrentAction`
  is only a deprecated wrapper for it. API doc: `RequiresValidActionSlot` (so pcall), `SecretArguments = "AllowedWhenUntainted"`.
- `C_Spell.PlaceTargetingSpellAtCursor` exists but is restricted (`HasRestrictions = true`), so addon code cannot call it.
Not verified (needs the game): that `IsCurrentAction` is true for the spell that is waiting for a ground spot; which class/spell the user tried
first (their `/ubf ground` report said no ground spell was found, so that spell was probably not in the built-in list).

## 1.3.32: switched to UbermocUI's method (works in the user's game)
UbermocUI `Aim.lua` learns a ground spell by hooking `PreClick` of each bar button: if the game is not aiming at the press and
`SpellIsTargeting()` is true 0.1 s later, that button's spell is a ground spell; it is saved to the player's own list. Then it sets
`typerelease = macro` and `macrotext = /stopspelltarget` + `/cast [@cursor] <Spell>` on that button, out of combat, and turns on the CVars
`ActionButtonUseKeyDown` and `ActionButtonUseKeyHeldSpell`. The override-key method and the `IsCurrentAction` scan of 1.3.27 to 1.3.31 were
replaced by this, because it is the one the user has seen work. Ours keeps its marks in its own tables (no fields written on the game's
buttons) and saves/restores those two CVars (`groundBackup`). Whether the earlier taint errors came from this kind of attribute is not proven.
