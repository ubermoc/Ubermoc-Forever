# Ubermoc-Forever

A controller-first interface for World of Warcraft: Forever, built for the Steam Deck and Steam Controller and working with PlayStation, Xbox and Nintendo Switch controllers. It uses only the game's own art and templates.

First feature: controller detection, a first-run prompt for the default key binds, an "Ubermoc Forever" entry in the game menu above Options (change or clear any bind, reset to default), and a legend of the controller buttons.

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
