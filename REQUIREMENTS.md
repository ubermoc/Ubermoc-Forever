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

## Open fact (do not guess it)
RESOLVED 2026-11-12: /ubermoc dumpdefaults on the user's game recorded Blizzard's real default controller layout — 15 bindings, saved in WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua and copied verbatim into Layout.lua (ns.BlizzardLayout) and the Spec tests.

## Design decisions and lessons (learned the hard way; read before touching bindings)
- The gamepad defaults only EXIST while Blizzard's gamepad UI is on: with it off, the recorded actions answer nothing (first dump: count 0). They live in bindingContext "GamepadModeInGameCore", which only Blizzard's own gamepad code activates (Blizzard_Gamepad/Core.lua:48-56). So reading them needed the context passed to GetBindingKey; applying them must NOT touch that context.
- Applying the layout uses OVERRIDE bindings on an addon-owned frame (the same mechanism Blizzard's gamepad UI itself uses, InputActionBinding.lua:22), never SetBinding/SaveBindings and never UIParent as owner. Overrides are temporary — re-applied every PLAYER_LOGIN. No popup answer means no binding.
- The user approved (2026-11-13, "just get the binds in there that are the blizzard ones"): apply Blizzard's own 15 action names exactly as recorded; do not substitute standard actions.
- Whether an override-bound GamepadModeInGameCore action actually FIRES with Blizzard's gamepad UI off is NOT proven offline — the user tests it in game (WHAT TO TEST list). If it does not fire, that finding goes here and line 3 needs a different mechanism.
- ANSWERED 2026-11-12 23:45 (user's in-game test): it does NOT fire. With the gamepad UI off, dump 2 recorded contextActive=false / count=0 even though our override claims were in place, and pressing the buttons did nothing. A SET binding is not a FIRE: an action whose bindingContext is inactive never runs, however it was set. The mechanism (override bindings on our own frame) was fine; the ACTIONS were the problem.
- Therefore ns.BlizzardLayout keeps the 15 recorded KEYS but binds them to Blizzard's own NORMAL-context actions read from shipped binding bodies (Bindings_Camelot.xml: ACTIONBUTTON1-8, OPENALLBAGS, TOGGLEGAMEMENU, JUMP, INTERACTTARGET...; see Layout.lua header for each cite). The four shoulder/trigger keys still carry the recorded GAMEPAD*MOD actions — they live in the SAME inactive GamepadModeInGameCore context (Blizzard_Gamepad/Bindings.xml:14-25), so they are EXPECTED DEAD with the UI off; kept only because dump 1 recorded them, and the user's button test decides whether to replace them next.
- The user's steer (2026-11-13): "bind it to the secondary slot in the blizzard binds" — interpreted as: use Blizzard's own always-on bindings rather than inventing anything. A literal second binding slot per action exists (the Key Bindings UI shows two keys per command; SetBinding mode 2 writes an alternative set, warcraft.wiki.gg/wiki/API_SetBinding) but writing the player's saved binding file needs SaveBindings and was NOT needed for this fix.
- ANSWERED 2026-11-13 (user decision, approved): the four dead GAMEPAD*MOD shoulder/trigger entries are REPLACED with working NORMAL-context actions. The layout is now ns.DefaultLayout, 20 keys covering every button the user listed: d-pad + face buttons -> ACTIONBUTTON1-8; PADFORWARD -> OPENALLBAGS; PADBACK -> TOGGLEGAMEMENU; PADRSTICK -> JUMP; PADLSTICK and PADLSHOULDER -> INTERACTTARGET; PADRSHOULDER -> TARGETNEARESTENEMY; PADLTRIGGER -> OPENCHATSLASH; PADRTRIGGER -> ACTIONBUTTON9 (Bindings_Camelot.xml:211-214); PADPADDLE1-3 -> ACTIONBUTTON10/11/12, PADPADDLE4 -> MULTIACTIONBAR1BUTTON1 (:396-407).
- The game translates EVERY controller (Steam Deck, Steam Controller, Xbox, PS3/4/5, Switch) into ONE fixed set of PAD key names — no per-controller code is needed (Blizzard_SharedXML/SharedConstants.lua:61-92 KEY_PADPADDLE1..4 / LSTICK / RSTICK / FORWARD / BACK; GamepadConstants.lua:7-8). Whether the PADDLE keys actually fire on a plain pad is UNVERIFIED — the user's press test decides.
- Press-to-bind (approved 2026-11-13): rows for all 20 default keys plus 4 chord rows; pick a row, press any controller button, that exact key is bound (capture via OnGamePadButtonDown on our own listener Button, like Blizzard's KeybindListener, Blizzard_Settings_Shared/Blizzard_Keybindings.lua:1-9,26-38). db.binds[row]=key is the single source of truth; "" means cleared on purpose; ApplyLayout clears our claimFrame and re-claims from it every login (ClearOverrideBindings, the frame's own claims only).
- Chord rows (SHIFT-/CTRL- prefixed) ship as ROWS ONLY, never claimed by default: whether chords fire on PAD keys is unproven offline. R-1.3 test forbids a "-" in any default claim.
