# Items used on other items: what the game's own data says

Taken in the game with `/ubf scan` (build 1.60.1): every item id 1 to 60000, kept when class 0 (consumable) or 8 with a "Use:"
line that names a weapon, armor or a slot. 986 candidates had data; the list below is what matched. The scan tool is
`UbermocForever/Scan.lua`; its output is in `UbermocForeverDB.scan` in the SavedVariables file.

| Kind | Example (id) | Class / sub | Use text (start) | Goes on |
| --- | --- | --- | --- | --- |
| Poison | Deadly Poison IV (8985), Crippling Poison (3775), Instant Poison III (6950) | 0 / 8 | "Coats a weapon with poison ..." | melee weapons (16, 17) |
| Weapon oil | Brilliant Wizard Oil (20749) | 0 / 8 | "While applied to target weapon ..." | melee weapons |
| Sharpening stone | Elemental Sharpening Stone (18262) | 0 / 8 | "Increase critical chance on a melee weapon ..." | melee weapons |
| Armor kit | Medium Armor Kit (2313) | 0 / 6 | "... of an item worn on the chest, legs, hands or feet." | the slots named |
| Scope | Deadly Scope (10546) | 0 / 14 | "Attaches a permanent scope to a bow or gun ..." | ranged slot (18) only |

Not on an item (the scan's false positives, which mention "armor" or "item" only in passing): Living Action Potion (20008),
Greater Stoneshield Potion (13455), Flask of Chromatic Resistance (13513).

Only 10 items matched, so the client knows few enchant scrolls; most enchanting goes through the profession. Poisons and
stones of other ranks were not in the client's item data.

`ItemMenu.lua` `M.targets(itemID)` turns the wording above into equipment slots. Unknown wording falls back to the melee weapons.

## Armor kits and head / leg / shoulder enchants (checked 2026-11-18)

Every such item in the Forever item data (QuestieDB `data/Forever/foreverItemDB.lua`, which also gives each item's class), with its
use text from Wowhead's Classic tooltips. Armor kits are class 0 (consumable); the arcanums, the Zandalar signets and the Scourge
enchants are class 12 (quest); the Zul'Gurub enchants and guards are class 15 (miscellaneous). `M.usedOnItems` takes class 12 and 15
items whose use text says "slot item", and `M.targets` reads the slots from the text. All 37 are in `tools/smoke_test.py`.

| Goes on | Use text | Items |
| --- | --- | --- |
| Chest, legs, hands, feet | "Permanently increase the armor value of an item worn on the chest, legs, hands or feet by N." (Core Armor Kit: defense) | Rugged Armor Kit (15564), Core Armor Kit (18251), Light Armor Kit (2304), Medium Armor Kit (2313), Heavy Armor Kit (4265), Thick Armor Kit (8173) |
| Head, legs | "Permanently adds ... to a leg or head slot item. Does not stack with other enchantments for the selected equipment slot." | Lesser Arcanum of Rumination (11622), Lesser Arcanum of Constitution (11642), Lesser Arcanum of Tenacity (11643), Lesser Arcanum of Resilience (11644), Lesser Arcanum of Voracity (11645), Lesser Arcanum of Voracity (11646), Lesser Arcanum of Voracity (11647), Lesser Arcanum of Voracity (11648), Lesser Arcanum of Voracity (11649), Arcanum of Rapidity (18329), Arcanum of Focus (18330), Arcanum of Protection (18331), Presence of Might (19782), Presence of Sight (19787), Hoodoo Hex (19788), Prophetic Aura (19789), Syncretist's Sigil (19783), Death's Embrace (19784), Falcon's Call (19785), Vodouisant's Vigilant Embrace (19786), Animist's Caress (19790), Savage Guard (22635), Ice Guard (22636), Shadow Guard (22638) |
| Shoulders | "Permanently adds ... to a shoulder slot item." | Zandalar Signet of Mojo (20076), Zandalar Signet of Might (20077), Zandalar Signet of Serenity (20078), Power of the Scourge (23545), Resilience of the Scourge (23547), Might of the Scourge (23548), Fortitude of the Scourge (23549) |
