# Research: the gamepad layout (one bar for the controller), 1.3.73

The user's request (2026-11-17): a layout, called the gamepad layout, with ONE row of 12 buttons at the bottom. With no modifier it shows action bar 1, with the first modifier action bar 2, with the second action bar 3, with both
action bar 4 (whatever is usable right now). Everything else at the bottom goes: no glyphs (key labels), no fancy art or framing, no micro menu, no bags. Buttons with nothing on them are hidden and the rest move together, evenly,
with an adjustable distance. The user chose "empty buttons" as the meaning of "bars that are not occupied" (not whole empty bars). The idea is Ubermoc UI's action bars (`UbermocUI/ActionBars.lua`: `mode = "held"`, `hideEmpty`, `centerVisible`, `gap`, `hideGame`).

## Sources read
- `Blizzard_ActionBar/Shared/ActionBar.lua` `ActionBarMixin:ActionBar_OnLoad`: every button is created inside its own `ButtonContainer<i>` frame; the main bar's buttons are named `ActionButton<i>`, the others `<BarName>Button<i>`
  (`MultiBarBottomLeftButton1..12`, `MultiBarBottomRightButton1..12`, `MultiBarRightButton1..12`). The button is anchored `CENTER` of its container; the bar's layout (`UpdateGridLayout`) moves the containers.
- `Blizzard_ActionBar/Shared/MultiActionBars.lua` and `MultiActionBars.xml`: `MULTIACTIONBAR1BUTTON` = `MultiBarBottomLeft`, 2 = `MultiBarBottomRight`, 3 = `MultiBarRight`: the same bars `Binds.lua` fills for the four layers.
- `Blizzard_ActionBar/Shared/ActionButton.lua` (`GetActionButtonForID`, button mixin), `SecureTemplates.lua` (`CalculateAction`): a button's action number, asked with `HasAction`.
- `UbermocUI/ActionBars.lua` (read, not copied): re-anchors the game's own buttons to a frame of its own (`btn:SetPoint("BOTTOMLEFT", root, ...)` after `SetScale(root effective scale / parent effective scale)`), hooks `SetPoint` and
  `SetSize` to put a button back when the game moves it, keeps notes about buttons in its own weak tables (writing a field on a protected button taints it), `SetIgnoreParentAlpha(true)` on the buttons so the bar's alpha does not carry them,
  shows the held layer with alpha (the active row 1, the others 0), raises the held layer's frame level (only out of combat), moves empty buttons out of sight and out of the mouse's way, and asks the bar to lay itself out again only out of combat.
- `docs/LUA-WOW-GUIDE.md` section 3: protected frames are only moved out of combat; never write fields on Blizzard frames; secret values.
- `Fade.lua`: the game's bottom art are existing Fading elements (`mainbar`, `bar2`, `bar3`, `bar4`, `micro`, `bags`, `xpall`); `F.implicit` gives a value without an entry on the Fading page, an explicit setting there still wins.

## How it is built (GamepadBar.lua, BarsPage.lua)
- Out of combat: for each of the four layers the 12 buttons are split into shown and empty (`HasAction`); shown ones are centred in a row of total width `12*size + 11*gap`, evenly spaced; empty ones go to x = -5000 (out of sight and mouse).
  All four rows sit on the same spot. A layout asked for in combat waits for the end of the fight (`PLAYER_REGEN_ENABLED`).
- In combat only alpha changes: the held layer (`IsShiftKeyDown`, `IsControlKeyDown`, `IsAltKeyDown`: shift, ctrl, both) is 1, the others 0. Checked on `MODIFIER_STATE_CHANGED` and ten times a second.
- Art: `F.implicit` returns 0 for the art keys while the layout is on and Hide the game's art is on; the buttons' `HotKey` text is hidden. Nothing is drawn by us: no plates, no borders (Blizzard's own button art stays).
- Dragging something (a spell from the book): `GetCursorInfo()` non-nil keeps every slot, so there is a place to drop on.
- Turned off: every button gets back its saved points, scale and size, alpha 1 and follows its bar's opacity again.

## Not verified in the game
Everything (offline test only: layers, even centring, empty buttons, put back when off): that `IsShiftKeyDown` follows the controller's emulated modifiers (`GamePadEmulateShift/Ctrl`, `Binds.lua`) and `MODIFIER_STATE_CHANGED` fires for them; that `btn.action`
or `CalculateAction` gives the real slot for the main bar after a page change or a form; that the game does not move the buttons back (edit mode) faster than the hooks fix it; how it looks and sits with the user's edit mode layout;
that bars 2 to 4 are switched on in the game's action bar settings (a bar that is off is hidden by the game and so are its buttons); mouse clicks on stacked layers (only the held layer is raised). `/ubf bars` reports the settings and,
for each layer, how many buttons were found, how many the game shows and how many are empty.

## 1.3.74: what the user asked for next (2026-11-17)
- The gamepad bar needs its own fading; each button must show the controller button it is bound to; the game's art the layout hides must be hidden for good (no mouse-over brings it back) except the experience bar, micro menu and bags, which stay
  adjustable; everything the layout changes belongs in one place (the Bars page) including a button that opens the game's Edit Mode to move those parts.
- Bound button: `GetBindingKey("ACTIONBUTTON<n>")`, `"MULTIACTIONBAR1BUTTON<n>"`, `"MULTIACTIONBAR2BUTTON<n>"`, `"MULTIACTIONBAR3BUTTON<n>"` (Binds.lua `MAIN_BARS`) give the keys, such as `SHIFT-PAD3`; the base `PAD3` goes to `UF.glyph(pad)`
  (Layouts.lua, the game's own `KEY_PAD3_*` pictures). The pictures are font strings of a frame of ours (child of the root frame), never anything written on the game's buttons.
- Fading engine (`Fade.lua`): `F.forced[key]` (hidden for good, ignores the universal mouse-over opacity and the chat reveals), `F.target(key, active, isOver)` (the one place that decides an element's opacity), `F.editing()` (no fading while
  `EditModeManagerFrame` is shown, so a hidden part can be seen and moved), `F.GBAR` (element `gbar`, frame = our root frame `UbermocForeverGamepadBar`; the buttons ignore their parent's opacity, so `GamepadBar.refresh` multiplies the root's opacity in).
- Edit Mode: the game's `/editmode` does `if EditModeManagerFrame:CanEnterEditMode() then ShowUIPanel(EditModeManagerFrame)` (`Blizzard_ChatFrameBase/Mainline/SlashCommandsOverrides.lua`); the button does the same through `securecallfunction`.
  While it is open the layout gives the buttons back (`release`) and takes them again when it closes (polled ten times a second).
- Not touched: the stance, pet and possess bars and the extra action button (the user did not name them; they stay where the game puts them).
- Not verified in the game: all of it. Also open: whether the photo from the game (micro menu and bags still visible next to the layout row, no bound-button pictures yet) was the mouse-over opacity lifting them or an explicit Fading page setting that wins over the layout's default.
