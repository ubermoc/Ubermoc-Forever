# Ubermoc-Forever

A default UI for World of Warcraft: Forever that works 100% with a controller. It is designed specifically for the **Steam Deck** and the **Steam Controller**, and also works with PlayStation 5, Xbox and Nintendo Switch controllers. It uses only Blizzard's own art, frames and button pictures, so it looks like it has always been part of the game.

![The Ubermoc Forever entry in the game menu, directly above Options](docs/images/game-menu.jpg)

![The key binds window on a Steam Deck, with the four holds, the button pictures and the legend](docs/images/key-binds.jpg)

## What it does now

- Detects your controller and offers to set the default key binds the first time you play.
- Default binds in four layers: nothing held, Shift button held, Ctrl button held, both. The Steam Deck and Steam Controller hold R4 and R5; every other controller holds the triggers.
- Start steps like Esc: it closes what is open, clears your target, then opens the game menu.
- An "Ubermoc Forever" entry in the game menu, above Options. Change or clear any bind, or reset to default.
- Move around its windows with the D-pad, A, B, X and Y, without Blizzard's built-in controller interface. The legend changes to fit the page and the bumpers switch between the four holds.

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
