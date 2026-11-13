# Ubermoc Forever: requirements (the user's decisions, 2026-11-12; read this FIRST)

A World of Warcraft Forever addon (Forever only, interface 16001). Steam Deck and Steam Controller come first; every other controller must work too. The whole game must be playable with ONLY a controller: no mouse, no keyboard. Plug and play. It must look 100% like a Blizzard product: Blizzard templates and Blizzard art only, no custom art.

Hard limits: never send automated keyboard or mouse input to the game. Never name other people's addons in code, comments or docs. Do not invent actions, button assignments or layouts: the default layout is Blizzard's own.

## Spec
Each numbered line is an acceptance test. Tests name their line as R-1.N. A request that conflicts with a line needs the user's confirmation.

Phase 1, foundation and default binds
1. The addon loads on a brand-new install (no saved data, all defaults, no other Ubermoc addon) with no Lua error.
2. The first load on a new install shows ONE popup asking permission to apply the controller layout. Nothing is bound before the player says yes. "No" leaves the game's bindings untouched and the popup does not return on later logins; a slash command asks again.
3. The layout that gets applied is Blizzard's own default controller layout for Forever (the same assignments Blizzard's gamepad UI puts on the bars), applied WITHOUT the player switching on Blizzard's gamepad UI. The addon invents no actions and no layout of its own.
4. It works with the Steam Deck and Steam Controller first and also with Xbox, PlayStation and Switch controllers; button names and icons shown match the connected controller.

Phase 2, options and rebinding
5. An "Ubermoc Forever" entry in the game's Esc menu opens the options page; the same page is in the game's Options. Both are built from Blizzard templates and art.
6. The options page lists every controller binding the addon applied, in rows that look and work like Blizzard's own key-binding rows: choose a row, press a controller button, it is bound. A clear action clears ONLY that row. A button never silently ends up on two actions: the conflict is shown and resolved. "Reset to default" restores Blizzard's layout.
7. Changing one binding never changes any other binding. /reload and a new login keep exactly what the player set.
8. Every failure path (no controller, in combat, unknown action) leaves the bindings as they were and says so in chat.

Phase 3, moving around windows
9. When a game window is open (bags, character, quest log, vendor, popups, the options page), the d-pad moves a visible highlight between its buttons, one face button activates the highlighted button and another closes or backs out. No mouse is needed in any standard Blizzard window.
10. An option (off by default) lets the right stick move the mouse cursor, using the game's own gamepad cursor feature.

Phase 4, talking to NPCs and quests
11. In NPC gossip, quest offer, quest progress and quest completion windows, one face button accepts / continues / completes and another declines / goes back / closes; the window shows which button does what.
12. When such a window opens, the highlight snaps to the most relevant control: Accept on a quest offer, Continue, Complete Quest, or the first gossip option.
13. When a quest lets the player choose a reward, the d-pad moves between the reward items (showing each tooltip), a face button picks one, and the quest cannot be completed with no choice made when a choice is required.
14. Nothing in lines 1-13 ever requires a mouse or keyboard.

## Design decisions (2026-11-12; found by the Phase 1 Step A test)
D1. The addon SHIPS Blizzard's default controller layout as data (a table in its own file, with the Blizzard file:line and the date it was recorded from the Forever client). Players never run a diagnostic and never need to switch on Blizzard's gamepad UI first. `/ubermoc dumpdefaults` stays as a developer tool to re-record the layout after a game patch.
D2. Recorded from Forever 1.60.1 with Blizzard's gamepad UI on (context GamepadModeInGameCore active), 15 actions, no clashes: PADDLEFT/PADDUP/PADDRIGHT/PADDDOWN = GAMEPADACTIONBUTTON1/2/3/4; PAD3/PAD4/PAD2/PAD1 = GAMEPADACTIONBUTTON5/6/7/8; PADLTRIGGER = GAMEPADLEFTMOD; PADRTRIGGER = GAMEPADRIGHTMOD; PADLSHOULDER = GAMEPADLEFTTARGETMODIFIER; PADRSHOULDER = GAMEPADRIGHTTARGETMODIFIER; PADRSTICK = TOGGLEPINGSYSTEM; PADFORWARD = OPENRADIAL; PADBACK = TOGGLEUIFOCUS. Not yet known: what the trigger modifiers change (extra pages), and whether jump / interact / other gamepad actions live in other binding contexts.
D3. OPEN RISK, research before building spec line 3: these actions belong to the binding context GamepadModeInGameCore, which Blizzard turns on only with its gamepad UI (Blizzard_Gamepad/Core.lua:48-56). `C_KeyBindings.ActivateBindingContext` is marked HasRestrictions in the API docs (KeyBindingsDocumentation.lua:11-14). If an addon cannot activate that context, bindings on those actions will not fire with Blizzard's gamepad UI off. Find out with lookups what is allowed. If the plan needs a different approach (for example mapping the same keys to the regular action-bar commands), STOP and ask the user before choosing; do not invent a layout.
D4. Every sentence the addon shows the player (chat lines, popups, hints) that tells them to do something in the game (open a menu, tick a setting) must be verified against Blizzard's source, with the file:line in a code comment. The Gamepad UI setting is under Options > Gamepad (Blizzard_SettingsDefinitions_Shared/Gamepad.lua:274-291), not Controls.

## Open fact: RESOLVED for the 15 actions in D2 (read from the running game). Still open: see D2 (pages) and D3 (whether the context can be active without Blizzard's gamepad UI).
