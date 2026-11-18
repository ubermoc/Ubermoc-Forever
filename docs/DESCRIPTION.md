# Ubermoc Forever

A default UI for World of Warcraft: Forever that works 100% with a controller. It is designed specifically for the Steam Deck and the Steam Controller, and also works with PlayStation 5, Xbox and Nintendo Switch controllers.

It uses only Blizzard's own art, frames and button pictures, so it looks like it has always been part of the game.

## What it does now

- Detects your controller and offers to set the default key binds the first time you play.
- Nameplates mark the units your active quests are about with the game's small quest icon and show how far the objective has got ("3/8"); two buttons on the Quality of life page switch the mark and the progress on or off.
- Before you put a poison, oil, stone, armor kit or enchant on a piece you wear, a question in the middle of the screen tells you if it already carries a temporary poison or oil with time left and asks A for yes or B for no; for armor kits and enchants the game's own question (which names what is replaced) is used.
- B cancels the "pick the item it goes on" state after you use a poison, oil, armor kit or enchant from a bag (out of combat), so a controller player never needs the mouse to back out.
- The options window explains itself: a panel at the bottom describes the setting the highlight is on, and every setting has a description in plain words (the mouse tooltip says the same).
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
- Y on a bag in your bags puts it in one of your bag slots, showing on each slot how many more or fewer slots you would have. With your bags open, the highlight also reaches the bag bar: Y on a bag slot lists the bags you carry that fit it, with the same gain.
- Y on a locked box in your bags offers Pick Lock when your rogue knows it, with the Lockpicking skill it needs.
- Fast loot: with the game's Auto Loot on, everything is taken the moment the loot opens; the loot window only shows if something is left. Not while you are the master looter. Fast loot: On/Off on the Quality of life page of the options window.
- At a vendor: grey items are sold and your gear is repaired, paid from the guild bank first when your guild allows it, otherwise from your own money. Each can be switched off on the Quality of life page of the options window.
- Name-only nameplates, two buttons on the Quality of life page ("Enemies: name only", "Friendly: name only", both off by default): a nameplate shows the unit's name and level with no health bar; the game's pieces on that plate are made invisible and get their alpha back when the option goes off. Friendly players use the game's own name-only setting, and the value you had before is kept so it can be given back. Two more buttons on the same page, both on by default: "Name is the health bar" (the name keeps its colour, class colour for a player and the reaction colour otherwise, and the part standing for the missing health is a white copy of the same letters) and "Health percent" (the percent written to the right of the name in the reaction colour). Both only matter while a name-only button is on. Increased plate range, one more button on the same page under Nameplates ("Increased plate range: Off/On"): the game shows nameplates only up to a distance from the camera (its own values 45 yards for units and 40 for players, with no settings row for it); On writes 45 into both of the game's distance settings and Off gives back the values you had before; nothing is written during combat and what waits is applied when the fight ends. A single mouse-over opacity can bring any faded part back while you point at it; the Chat page can give each chat part its own. The chat edit box can sit above the chat window instead of under it (Chat page). Parts you do not set are never touched.
- On the character window, A on a gear slot opens the list of items that fit it (the game's own equipment flyout); A equips the one you pick, B closes the list.
- Start steps like Esc: it closes what is open, clears your target, then opens the game menu.
- An "Ubermoc Forever" entry in the game menu, above Options. Change or clear any bind, or reset to default. A legend of the buttons changes to fit the page, and the bumpers switch between the four layers.
- Move around the game's own windows (bags, character, spellbook, professions, map, mail, the game menu and question windows) with a highlight, without Blizzard's built-in controller interface:
  - D-pad moves a glowing highlight, A clicks, X right-clicks, and B closes the window you are in, then jumps to the next open one.
  - The bumpers change tabs and pages, and the triggers step the side tabs down the right of a window (or scroll a list). Lists scroll by themselves to follow the highlight, and the right stick scrolls a quest's text or a long list.
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

## Works together

Four projects made to be used together, so you can play World of Warcraft from the couch with only a controller:

- **[Ubermoc UI](https://github.com/ubermoc/Ubermoc-UI)** ([CurseForge](https://www.curseforge.com/wow/addons/ubermoc-ui)): the controller-first addon for Midnight and Forever. It makes the game playable without a mouse or keyboard.
- **Ubermoc Forever** (this addon): a default UI for Forever that works 100% with a controller, designed for the Steam Deck and Steam Controller.
- **[Ubermoc Speech](https://github.com/ubermoc/Ubermoc-Speech)**: a Decky plugin for typing. Hold a button, speak, and your words are typed into chat or anything else with focus.
- **[Ubermoc Warcraft Mod Updater](https://github.com/ubermoc/Ubermoc-Warcraft-Mod-Updater)**: a Decky plugin that installs and updates these addons from GitHub releases in Gaming Mode.

## Install

Install it with the Ubermoc Warcraft Mod Updater, or copy the `UbermocForever` folder into your Forever `Interface/AddOns` folder.

Source: https://github.com/ubermoc/Ubermoc-Forever

## Support the project

Ubermoc Forever is free. If you'd like to say thanks, donations are optional and always appreciated:

- [GitHub Sponsors](https://github.com/sponsors/ubermoc)
- [Ko-fi](https://ko-fi.com/ubermoc)
- [Buy Me a Coffee](https://buymeacoffee.com/Ubermoc)

Made by Marcos ([Ubermoc](https://github.com/ubermoc)).
