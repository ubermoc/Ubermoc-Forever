# Quest direction arrow — sourced notes

Base for paths: `~/Downloads/Project Support/Ubermoc-Forever - WoW Research and Tools/`.
Claims as recorded in `.harness/proof.json` (C5–C15). Built 2026-11-19; implemented in `UbermocForever/QuestArrow.lua`.

## What the game can tell us

1. `C_QuestLog.GetQuestsOnMap(uiMapID)` returns `QuestPOIMapInfo` rows (claim C11,
   `blizzard-ui-source-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua:579-591`):
   `Name = "GetQuestsOnMap"`, `{ Name = "uiMapID", Type = "number", Nilable = false }`,
   `{ Name = "quests", Type = "table", InnerType = "QuestPOIMapInfo", Nilable = false }`.
   A row carries `questID`, `mapID`, `x`, `y` and `inProgress` (claim C12,
   `QuestInfoSharedDocumentation.lua:27-53`).
2. `C_Map.GetBestMapForUnit("player")` gives the map we are on, or nil (claim C13,
   `MapDocumentation.lua:49-62`).
3. `C_Map.GetPlayerMapPosition(mapID, "player")` returns `position` as `vector2` with the
   `Vector2DMixin`, or nil (claim C14, `MapDocumentation.lua:437-455`).
4. `C_Map.GetMapWorldSize(mapID)` returns `width` and `height`, the size in yards of the area the map
   represents (claim C15, `MapDocumentation.lua:420-436`). ForeverPlusPlus notes it can be nil when the
   game cannot say (`ForeverPlusPlus/ForeverPlusPlus/Lib/WorldMap.lua:312-326`) — so the code checks it.
5. `C_QuestLog.GetNextWaypointForMap(questID, uiMapID)` returns `x` and `y` when the quest has a
   waypoint on that map (claim C5, `Atraeau-WoW-Addons/types/WowForeverAPI.lua:23370-23377`); Blizzard's
   own tracker prefers it over the row position (`QuestNavigationWorldMapTemplate.lua:366-388`).
6. `GetPlayerFacing()` returns a number that can be nil (claim C6,
   `PlayerScriptDocumentation.lua:828-834`).

## The maths

- Bearing: `east = (toX - fromX) * width`, `south = (toY - fromY) * height`,
  angle = `atan2(-east, -south) % (2 * pi)` — counter-clockwise from north, 0 to 2 pi, like
  `GetPlayerFacing`, so an arrow pointing ahead turns by `angle - facing` (claim C7,
  `ForeverPlusPlus/ForeverPlusPlus/Lib/WorldMap.lua:341-355`).
- Blizzard's own quest arrow: `Vector2D_CalculateAngleBetween` is `atan2(cross, dot)` (claim C8,
  `Blizzard_SharedXML/Vector2D.lua:43-45`) and the arrow turns with `SetRotation(-angle)` (claim C9,
  `Blizzard_QuestNavigation/SuperTrackedFrame.lua:143-158`).
- The arrow art is Blizzard's own quest navigation atlas `Navigation-Tracked-Arrow` (claim C10,
  `Blizzard_QuestNavigation/SuperTrackedFrame.xml:14`). No new art, no new colour.

Test values (offline test case): from (0.2, 0.2) to (0.2, 0.7) on a 100x100-yard map = 50 yards,
angle pi (south); east case (0.6, 0.2): angle 3 pi / 2. Facing pi/2 (east), objective south:
turn = -(pi - pi/2) = -pi/2.

## Limits (stated, not guessed)

- The arrow points at a quest in progress **on the map you are on**; a quest whose spot is on another
  map is not pointed at (`mapID` on the row must equal the current map).
- Nothing shows when the game cannot say the player's spot, the map size, or the facing.
- Display-only: no click, no `/use`, no targeting, so no taint path (LUA-WOW-GUIDE §3/§8).
- In-game check at install time: `C_QuestLog.GetQuestsOnMap(1416)` printed 4 rows, all with
  `questID`, `mapID`, `x`, `y`, `inProgress` (`evidence:E11`, as reported by the author 2026-11-19).
