# Ubermoc-Forever

Current version: 1.3.172.

A default UI for World of Warcraft: Forever that works 100% with a controller. It is designed specifically for the **Steam Deck** and the **Steam Controller**, and also works with PlayStation 5, Xbox and Nintendo Switch controllers. It uses only Blizzard's own art, frames and button pictures, so it looks like it has always been part of the game.

![The Ubermoc Forever entry in the game menu, directly above Options](docs/images/game-menu.jpg)

![The key binds window on a Steam Deck, with the four holds, the button pictures and the legend](docs/images/key-binds.jpg)

## Screenshots

![The game on a first login: its own bars, the objective tracker and every frame in the default layout.](docs/images/first-login.jpg)

*The game as it looks on a first login, before anything is set up.*

![The gamepad layout turned on: one row of action buttons at the bottom with the controller button pictures X, A, B and Y.](docs/images/gamepad-first-login.jpg)

*The gamepad layout on a first login: one row of the game's own action buttons at the bottom, each with the controller button it is bound to.*

![The Bars page of the options window: gamepad layout, button size, gap, height, face button colours, other binds and the fading of each part.](docs/images/gamepad-layout-options.jpg)

*The Bars page of the options window: everything the gamepad layout changes is in one place.*

![Fading in use: the interface is faded out of the way and the bags show in the corner.](docs/images/mouse-over-bags.jpg)

*Fading in use: almost the whole interface is out of the way, and the parts you choose come back when you point at them.*

![In an instance out of combat: only the player frame and the minimap are left on screen.](docs/images/instance-no-combat.jpg)

*In an instance out of combat: only the player frame and the minimap are left on screen.*

![Travelling on a flight path with the interface faded completely.](docs/images/traveling-immersion.jpg)

*Travelling: on a flight path the interface fades out completely.*

![Out of combat while questing: only the gamepad row and the player frame are on screen, and an ability's tooltip shows when you point at it.](docs/images/out-of-combat-tooltip.jpg)

*Out of combat: the gamepad row and little else. Pointing at a button shows its tooltip.*

![In combat: the target frame, the experience bar and the minimap come back, with the gamepad row at the bottom.](docs/images/in-combat.jpg)

*In combat the target frame, experience bar and minimap come back by themselves.*

![The mailbox opened with a controller: the gold highlight on a letter and a legend under the window (A Select, B Close, X Take all, bumpers change tab), with the bags open.](docs/images/controller-mailbox.jpg)

*The game's own windows with a controller: a highlight moves with the D-pad and a legend under the window says what each button does. X takes everything from the mail.*

![The Y menu on a poison in the bags: Use, Use on Main hand, Use on Off hand, Pick up, Delete and Sort bags.](docs/images/item-menu-poison.jpg)

*Y on a bag item opens a menu: a poison can go straight onto your main hand or off hand weapon.*

![The Y menu on an armor kit: Use on Chest, Legs, Feet or Hands, each naming the item it goes on.](docs/images/item-menu-armor-kit.jpg)

*An armor kit offers every piece of gear it can go on, by name.*

![The character window: A on a gear slot opened the equipment flyout, with the game's compare tooltip beside it.](docs/images/equipment-flyout.jpg)

*On the character window, A on a gear slot opens the game's equipment flyout to swap pieces, with the compare tooltip.*

![The spellbook: Y on a spell offers Bind to action bar.](docs/images/spellbook-bind.jpg)

*Y on a spell in the spellbook binds it to your action bar: press the button combination you want it on.*

![A custom nameplate: the unit's name with its health percent in red beside it, no health bar, and the level in the game's own spot.](docs/images/nameplate-name-as-health.jpg)

*Custom nameplates: no bar, just the name and the health left. The name carries the health, and the percent sits beside it in the reaction colour.*

![Name-only nameplates on a friendly player and two animals, each with its level and health percent; a damaged animal shows 37 percent in yellow.](docs/images/nameplates-health-and-levels.jpg)

*Name-only plates: friendly players keep their level, and the percent changes colour as an enemy is hurt (green near full, yellow, then red).*

![Ironforge crowd: every player has a name-only nameplate with a health percent, with the controller mailbox and the bags open.](docs/images/nameplates-crowd-mail-bags.jpg)

*A crowded city stays readable: name-only plates instead of a wall of health bars, with the controller mailbox and the bags open.*

![The Settings page of the options window: cinematic mode, bar and edge thickness, the four layers of binds and the list of actions to change.](docs/images/options-settings.jpg)

*The Settings page: cinematic camera, the four bind layers (nothing held, P1, P3, both) and every button's action, with a description of what the highlighted setting does.*

![The Quality of life page: aim dot, fast loot, vendor selling and repair, and the nameplate options.](docs/images/options-quality-of-life.jpg)

*The Quality of life page: aim dot, fast loot, sell junk and repair at a vendor, name-only plates, quest marks and progress, friendly level, increased plate range.*

![The Bars page: gamepad layout, button size, gap, face button colours and the fading of the gamepad bar, XP bar, micro menu and bags.](docs/images/options-bars.jpg)

*The Bars page: the gamepad layout and how each leftover part (gamepad bar, XP bar, micro menu, bags) fades in combat, on a flight path and out of combat.*

![The Chat page: chat fade, how long lines stay visible, reveal on message, per-part opacity and the edit box on top.](docs/images/options-chat.jpg)

*The Chat page: lines that fade by themselves, reveal on a new message, opacity for each chat part and the edit box above the window.*

![The Fading page: about a hundred interface elements in groups, each with in combat, on a flight path and out of combat opacity.](docs/images/options-fading.jpg)

*The Fading page: roughly a hundred interface elements in groups, each with its own opacity in combat, on a flight path and out of combat.*

![Cinematic camera while talking to a gryphon master: black bars top and bottom, dark edges, the dialog window on the left with the controller legend, and everything else hidden.](docs/images/cinematic-gossip.jpg)

*Cinematic camera: when you talk to an NPC the camera moves in, black bars and dark edges come in, the rest of the interface is hidden, and the dialog shows what each controller button does.*

## What it does now

- Detects your controller and offers to set the default key binds the first time you play.
- Default binds in four layers (nothing held, Shift button held, Ctrl button held, both). Steam Deck and Steam Controller hold R4 and R5; every other controller holds the triggers. Bumpers target the nearest enemy and friend; Select is the map (with Shift all bags, with Ctrl the character panel, with both the spellbook); interact and jump are on the back buttons.
- Cinematic camera while you talk to a quest giver or gossip NPC: the camera moves in and turns to the NPC, black bars (thickness adjustable) and dark cloudy edges (how far they come in adjustable) come in, nameplates and everything else except the dialog and tooltips are hidden, while the game's own quest window stays exactly as it is. Everything is put back when the talk ends. /ubf cinema off turns it off.
- Quest and gossip windows show the A or B picture on the game's own Accept, Decline and Goodbye buttons, which keep their normal look. They are part of cinematic mode: /ubf cinema off hides them.
- An NPC with exactly one quest and nothing else to say opens that quest's Accept / Decline page by itself (part of cinematic mode). The game's "experimental feature" warning that a camera change would raise is closed for you while a talk starts.
- Chat lines that fade out by themselves a few seconds after they appear (starting at 5 seconds, then a 3 second fade), with the time settable in the options window. A Chat page of its own holds these settings and the opacity of each chat part (window, tabs, edit box, buttons); a faded chat window and edit box appear while a line arrives or you type, then fade back the same way. Every chat part (window, tabs, edit box, buttons) can hide itself until you use the chat and fade out a few seconds after; only the chat window shows on a new message.
- Interact on an enemy, a player, or a target you cannot interact with opens its right-click unit menu next to the target frame, with the highlight on the top entry. A corpse to skin, something to loot or an NPC next to you still gets the key first. It works on enemies in combat too (`/ubf targetmenu off` turns it off).
- A on "Target Marker Icon" in that menu opens a marker menu built with the game's own menu code (the game's marker names and icons, 8 down to 1 then None): A sets the marker and closes the menus, B closes the menu.
- A gamepad layout (Bars page): one row of the game's own action buttons at the bottom that shows action bar 1, 2, 3 or 4 as you hold the modifiers, each button with the controller button it is bound to (hanging over its top edge, and the other binds of the held combination such as jump or targeting get a slot with their name, the face buttons in black and white unless you choose colour). Cooldowns show the game's countdown numbers with a bright line sweeping round instead of the dark swipe, and an ability out of range gets a slight red hue on its button picture. The game's bottom art is hidden for good (no mouse-over brings it back) and empty buttons are removed; the end caps (dragons) are hidden with the rest. The micro menu, bags and XP bar stay where the game puts them (the first time, a question offers to open Edit Mode; later the Move bars button does); they, and the bar itself, have their own fading there, and a button opens the game's Edit Mode to move them.
- A new install starts with the author's own settings (the gamepad layout on, the fading values, the chat and cinematic settings); an install that already has settings is not changed. Our question windows say which controller button answers them (A, B, or X for a third choice), and the layout offers to open the game's Edit Mode to move the micro menu, bags and XP bar, and to open Gameplay > Action Bars when a bar you use is switched off.
- A white aim dot for ground spells (Heroic Leap, Blizzard, Rain of Fire), shown only while you aim one, with an aim distance and dot size setting on the Quality of life page of the options window.
- Quest direction arrow: while a quest is in progress, a small arrow near the top right of the screen points at its objective and turns as you turn. Four ways to aim it (a row on the Quality of life page steps through them): Direct, the straight line from you to the objective; Route, the game's own route data, which follows the roads and paths the game plans (when the game gives a route step for the quest; otherwise it is straight); and Around obstacles, which points straight at the objective and bends along the game's route only where that route shows something in the way, going back to straight once the way is clear; and Breadcrumbs, which points at waypoints along the trail you have walked (so a trip goes round the lake or cliff you once walked round) and, for another continent, at the boat, zeppelin or tram you have ridden for your faction, with a line under the arrow saying what the next step is. The game gives addons no terrain, water or dock data, so Around obstacles reads the obstacle from the game's route, and Breadcrumbs learns from your play: where you walk on foot, the rides you take and the dungeon entrances you use (kept only in your own saved settings, never sent anywhere; `/ubf learned` says how much it knows). Until you have walked or ridden somewhere it points straight and says so. The arrow turns with your view: it points toward the game's own on-screen marker for the objective, and where the game gives no marker position it points by where the objective lies from where your character faces. There is no setting for it. It is the old minimap quest arrow, with the distance under it, and it points at the quest selected in the tracker (or else the first quest in progress on your map). Buttons beside the on/off button on the Quality of life page set the aim, the size (16 to 128 pixels, one step per press), the opacity (100 down to 10 percent, in steps of ten) and the place (six places, or drag it with a mouse or the trackpad and it stays where you drop it, kept per character). On by default. `/ubf arrow` shows what the game answers for it and why the arrow is hidden when it is.
- Y on a bag in your bags puts it in one of your bag slots, showing on each slot how many more or fewer slots you would have. With your bags open, the highlight also reaches the bag bar: Y on a bag slot (on the bag bar, or in the bag window with a controller) lists the bags you carry that fit it, each with the slots it gains in green or loses in red; A swaps it in.
- Y on a locked box in your bags offers Pick Lock when your rogue knows it, with the Lockpicking skill it needs.
- Fast loot: with the game's Auto Loot on, everything is taken the moment the loot opens; the loot window only shows if something is left. Not while you are the master looter. Fast loot: On/Off on the Quality of life page of the options window.
- At a vendor: grey items are sold and your gear is repaired, paid from the guild bank first when your guild allows it, otherwise from your own money. Each can be switched off on the Quality of life page of the options window.
- Name-only nameplates on the Quality of life page: "Enemies: name only" and "Friendly: name only" (both on by default). A plate shows the unit's name with no health bar: the game's bar, level and highlight pieces on that plate are made invisible (alpha 0), and each one gets back the alpha it had when the option goes off. Friendly players use the game's own name-only setting, whose previous value is kept so it can be given back. Two more buttons on the same page, both on by default: "Name is the health bar" — the name keeps its colour (class colour for a player, reaction colour otherwise) and the part standing for the missing health is a white copy of the same letters, clipped by a bar of ours — and "Health percent", the percent written to the right of the name in the reaction colour. They only matter while one of the name-only buttons is on; both off gives the plain name look.
- Increased plate range, one more button on the same page under Nameplates ("Increased plate range: Off/On"). The game shows nameplates only up to a distance from the camera (its own values: 45 yards for units, 40 for players) and has no settings row for it. On writes 45 into both of the game's distance settings (so players' plates reach as far as units'); Off gives back the values you had before. Nothing is written during combat, and what waits is applied when the fight ends.
- A Fading page in the options window: set how see-through each part of the game's interface is (about 110 parts: the main bar's end caps and border, every action bar, unit frames in parts, the minimap in parts, the objective tracker, chat, menus, alerts, widgets, nameplates) in combat, on a flight path and out of combat, from 0 to 100 % or hidden for good. A single mouse-over opacity can bring any faded part back while you point at it. Parts you do not set are never touched.
- On the character window, A on a gear slot opens the list of items that fit it (the game's own equipment flyout); A equips the one you pick, B closes the list.
- Start steps like Esc: it closes what is open, clears your target, then opens the game menu.
- An "Ubermoc Forever" entry in the game menu, above Options. Change or clear any bind, or reset to default. A legend of the buttons changes to fit the page, and the bumpers switch between the four layers.
- Move around the game's own windows (bags, character, spellbook, professions, map, mail, the game menu and question windows) with a highlight, without Blizzard's built-in controller interface:
  - D-pad moves a glowing highlight, A clicks, X right-clicks, and B closes the window you are in, then jumps to the next open one. On a bag item X does the item's own right click, which uses it: a recipe is learned, a hearthstone, a poison, an armor kit, an oil or a stone is used, a bag is equipped, and at a vendor the item is sold. The legend shows X ("Use" over an item, "Right-click" at a vendor) whenever X has something to do. The Y menu keeps its own entries for poisons, oils, sharpening stones, armor kits and enchants, and lists the pieces you wear that they fit. If something does nothing, `/ubf x` shows what X resolves to on the highlighted item and `/ubf errors` lists any error the addon caught.
  - The bumpers change tabs and pages, and the triggers step the side tabs down the right of a window (or scroll a list) — but only when the window has a stack of side tabs or a list under the highlight. With nothing to page or scroll the triggers stay your own bind, so a spell put on the right trigger still fires. Lists scroll by themselves to follow the highlight, and the right stick scrolls a quest's text or a long list.
  - Drop-down menus open and the highlight jumps into them; new windows, like an opened letter in the mail, take the highlight.
  - A legend under each window lists what every button does there, and the item's tooltip shows beside the highlight on whichever side has room.
  - Quest and gossip windows start on their first option (or the Accept, Continue or Complete button). A accepts, B declines.
  - Trainers: A selects a skill, X trains it.
  - Mailbox: X on a mail with an item or money takes everything in it.
- Y opens a small menu on what the highlight is over:
  - A bag item: use or sell (at the auction house: Sell at auction, and Create auction once an item waits in the sell slot), use on the piece it fits (poisons, sharpening stones and oils on your weapons, armor kits on the armor they name, scopes on your ranged weapon), disenchant, prospect, mill, pick up, delete, sort bags.
  - A worn item: use it, or use anything from your bags that fits it, or pick it up.
  - A spell in the spellbook: bind it by pressing buttons. Hold your paddles and press the button you want (a back button that Steam Input turns into a key works too). If that combination already triggers an action slot, the spell goes there. If it is free, the spell goes in the first empty slot on a visible bar and the combination is bound to it. If it is already used for something else, the game asks if you want to replace it.
- In combat your buttons go straight back to your own binds. Windows stay open but do not take your buttons, and they will not open in combat.

The full description is in [docs/DESCRIPTION.md](docs/DESCRIPTION.md).

## Works together

Four projects made to be used together, so you can play World of Warcraft from the couch with only a controller:

- **[Ubermoc UI](https://github.com/ubermoc/Ubermoc-UI)** ([CurseForge](https://www.curseforge.com/wow/addons/ubermoc-ui)): the controller-first addon for Midnight and Forever. It makes the game playable without a mouse or keyboard.
- **Ubermoc Forever** (this addon): a default UI for Forever that works 100% with a controller, designed for the Steam Deck and Steam Controller.
- **[Ubermoc Speech](https://github.com/ubermoc/Ubermoc-Speech)**: a Decky plugin for typing. Hold a button, speak, and your words are typed into chat or anything else with focus.
- **[Ubermoc Warcraft Mod Updater](https://github.com/ubermoc/Ubermoc-Warcraft-Mod-Updater)**: a Decky plugin that installs and updates these addons from GitHub releases in Gaming Mode.

## Install

Clone this repo, then from its folder:

```bash
bash tools/install.sh
```

It finds your Forever addon folder (Steam, an SD card, Lutris) and copies the addon in. Run it again to update. `--link` links it instead so changes show after `/reload`; `--uninstall` removes it. Or pass the folder yourself: `bash tools/install.sh "/path/to/_forever_/Interface/AddOns"`.

## Research and tools

- `bash tools/setup-research.sh` builds a folder of reference material (Blizzard's Forever UI code, API dump, sample addons) in Downloads.
- `docs/RESEARCH.md` is what we know about the Forever client, where each fact came from, and what is still unverified.
- `python3 tools/smoke_test.py` (needs `pip install lupa`) checks the addon offline against a stub of the game.

## Support the project

Ubermoc Forever is free. If you'd like to say thanks, donations are optional and always appreciated:

- [GitHub Sponsors](https://github.com/sponsors/ubermoc)
- [Ko-fi](https://ko-fi.com/ubermoc)
- [Buy Me a Coffee](https://buymeacoffee.com/Ubermoc)

Made by Marcos ([Ubermoc](https://github.com/ubermoc)).
