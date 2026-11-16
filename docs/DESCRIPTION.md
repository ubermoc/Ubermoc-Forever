# Ubermoc Forever

A default UI for World of Warcraft: Forever that works 100% with a controller. It is designed specifically for the Steam Deck and the Steam Controller, and also works with PlayStation 5, Xbox and Nintendo Switch controllers.

It uses only Blizzard's own art, frames and button pictures, so it looks like it has always been part of the game.

## What it does now

- Detects your controller and offers to set the default key binds the first time you play.
- Default binds in four layers (nothing held, Shift button held, Ctrl button held, both). Steam Deck and Steam Controller hold R4 and R5; every other controller holds the triggers. Bumpers target the nearest enemy and friend; Select is the map; interact and jump are on the back buttons.
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
  - A bag item: use or sell, use on the piece it fits (poisons, sharpening stones and oils on your weapons, armor kits on the armor they name, scopes on your ranged weapon), disenchant, prospect, mill, pick up, delete, sort bags.
  - A worn item: use it, or use anything from your bags that fits it, or pick it up.
  - A spell in the spellbook: bind it to an action bar, then pick the slot.
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
