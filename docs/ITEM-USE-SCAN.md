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
