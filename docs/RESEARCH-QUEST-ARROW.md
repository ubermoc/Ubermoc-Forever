# Quest arrow research

Sources are Blizzard's Forever UI (`blizzard-ui-source-forever/Interface`) and its API index
(`AddOns/Blizzard_APIDocumentationGenerated`). Short names: `R` is the Interface folder, `D` is the API
index inside it. Claim numbers are the ones recorded in the harness (`proof status`); the offline test
blocks in `tools/smoke_test.py` are marked `FAKE(C<n>)` against them.

## What the client gives, and what it does not

- **No walkability data.** A search of the whole Forever source and the API index for navmesh, walkability,
  pathfinding, terrain and obstacle terms returns nothing (`R`, `D`: 0 hits; evidence **E50**). So mode 3
  cannot be a real route around obstacles: it is the closest thing the client allows, which is the map
  areas (see below). The options row and the code say this plainly.
- **No route for a quest from the content tracker.** `ContentTrackingType` has four values — Appearance,
  Mount, Achievement, Decor — and none is a quest (`D/ContentTrackingTypesDocumentation.lua:60-72`, C30),
  so `GetNextWaypointForTrackable` (C18) is not used for quests.

## Art, size, rotation

- The quest navigation picture is the atlas `Navigation-Tracked-Arrow` (C10).
- Blizzard's own arrow is a `100` x `100` frame with `useAtlasSize`, anchored `CENTER`, with a distance line
  on `GameFontNormal` (`R/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.xml:5-24`, C39).
- `AtlasInfo` answers `width` and `height`, so the size we draw is a share of the size the game gives the
  atlas (`D/TextureUtilsDocumentation.lua:207-224`, C42). Three sizes: 0.75, 1, 1.35.
- `SetRotation` turns a picture COUNTER-clockwise by what it is given (Blizzard's own arrow gives it the negative of a clockwise
  screen angle, `SuperTrackedFrame.lua:152`; ForeverPlusPlus's compass arrow gives `+pi/2` for an arrow that points left,
  `CompassBar.lua:690`). The bearing to a point on a map is `atan2(-east, -south)` modulo 2 pi, north at 0, counter-clockwise (C7), and
  the facing `GetPlayerFacing` is counter-clockwise from north too (C6), so `angle - facing` is how far counter-clockwise from
  straight ahead the objective lies and the arrow turns by exactly that, `SetRotation(angle - facing)`, as ForeverPlusPlus's
  waypoint arrow does. Up to 1.3.160 the code gave `-(angle - facing)` (a misreading of claim C9, which is Blizzard's clockwise
  screen angle): the arrow pointed to the mirror image of the objective. Facing west is `pi / 2`, facing east `3 pi / 2`.
- The frame is clamped to the screen with `SetClampedToScreen` (`D/SimpleFrameAPIDocumentation.lua:1207-1216`, C38),
  and it keeps one anchor because `ClearAllPoints` clears all its points
  (`D/SimpleScriptRegionResizingAPIDocumentation.lua:22-30`, C43).

## The target, including another map

- The quest the game has focused on: `GetSuperTrackedQuestID` (C20).
- The map the quest route is on: `GetNextWaypoint(questID)` answers `mapID`, `x`, `y`
  (`D/QuestLogDocumentation.lua:251-265`, C23). The `QuestInfo` structure has no map field
  (`D/QuestLogDocumentation.lua:1547`), so this is the only way to get a quest onto its own map.
- The rows for the map we are on: `GetQuestsOnMap` (C11), rows carrying `questID`, `mapID`, `x`, `y`,
  `inProgress` (C12). The map we are on: `GetBestMapForUnit` (C13); our position on it (C14); its size in
  yards for the distance line (C15).
- Blizzard shows its own arrow only while the quest is clamped (`R/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.lua:158`, C40),
  and writes the distance when it is not clamped, `Round(C_Navigation.GetDistance())`
  (`SuperTrackedFrame.lua:201-205`, C41). Our distance is yards from map fractions times the map size, with
  `~` when the point is on another map, because that is a straight line, not a walked route.

## The three modes

1. **Direct** — the straight bearing from our position to the objective, taken on the map the objective is
   on, or on the map that holds both areas when it is elsewhere.
2. **Route** — the games own route data for the map we stand on: `GetNextWaypointForMap(questID, uiMapID)`
   (C5), then `C_Navigation.GetNextWaypointForMap(uiMapID)` (`D/InGameNavigationDocumentation.lua:39-53`, C29).
   Read again as we move; nothing is stored.
3. **Around areas** — the map hierarchy the game exposes: `GetMapChildrenInfo` lists the areas on a map
   (`D/MapDocumentation.lua:197-214`, C24), `GetMapInfo` answers `parentMapID` (`:312-326`, C27, fields at
   `:696-706`, C25), and `GetMapRectOnMap(childMapID, parentMapID)` gives the rectangle of an area on the
   map above it (`:400-418`, C26), used exactly that way by Blizzards own zone labels
   (`R/AddOns/Blizzard_SharedMapDataProviders/ZoneLabelDataProvider.lua:39`, C28). From our position the
   arrow aims at the border of the next area on the way up to the shared map; inside a single area there is
   nothing to route around, so there it is the straight line. This is the honest limit of mode 3: see the
   walkability note above.

## Place and size, without Edit Mode

- `RegisterEditableExemplar` (the Move bars system) does not exist in the Forever source or API index
  (0 hits; evidence **E51**), so an addon frame cannot join it. The frame instead takes its own drags:
  `EnableMouse(true)` (`D/SimpleScriptRegionAPIDocumentation.lua:73-83`, C34) and
  `RegisterForDrag("LeftButton")` (`R/AddOns/Blizzard_ActionBar/Shared/SpellFlyout.lua:25`, C22), with the
  games handler names `OnDragStart` and `OnDragStop` (`R/AddOns/Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml:142-181`, C37).
- While a drag is held the cursor is followed: `GetCursorPosition` answers `posX`, `posY`
  (`D/InputDocumentation.lua:30-38`, C31), divided by the frames effective scale exactly as Blizzard does
  (`R/AddOns/Blizzard_SharedXML/InputUtil.lua:9-13`, C32), then put into the screen rect (`GetRect`:
  `left, bottom, width, height`, `D/SimpleScriptRegionAPIDocumentation.lua:193-207`, C33).
- The place is kept per character as fractions of the screen, and applied with `SetPoint` in `uiUnit`
  (`D/SimpleScriptRegionResizingAPIDocumentation.lua:135-148`, C35); the size is applied with `SetSize`
  (`:163-173`, C36). Default place: `fx 0.88, fy 0.90`, default size Medium.
- Nothing here clicks, uses or targets, so nothing can taint (`docs/LUA-WOW-GUIDE.md` sections 3 and 8).

## Mode 3, around obstacles (1.3.159)

The client has no terrain, water or collision data, so the arrow cannot see an obstacle. It can read one from the game's own route,
which is made with that data: `Q.bends` compares the bearing of the route's next step (`GetNextWaypointForMap`, mode 2's source) with the
straight bearing to the objective. While the two agree within 35 degrees (20 once a bend is under way) the arrow stays straight; when the
step swings further away, the arrow follows the step. With no route answer from the game it is the straight line and `/ubf arrow` says
"no route from the game". Limit: a winding road across open land also swings the step, so there it follows the road. The map-area
borders of 1.3.146 are still used when the objective is on another map.

## How the arrow turns (1.3.166), from two working examples

Read, not guessed (both are Forever addons the user runs; ThePath is kept next to the other research in `ThePath-1.6.2/`):

- **ForeverPlusPlus** `Modules/Map/Waypoints.lua` `update()`: `frame.arrow:SetRotation(angle - facing)` with `angle` from `WorldMap.Toward`
  (`atan2(-east, -south) % 2 pi`, north 0, counter-clockwise) and `facing = GetPlayerFacing()`.
- **ThePath** `Nav.lua` `N:Paint()`: `angle, dist = HBD:GetWorldVector(...)`, then `f.tex:SetRotation(angle - facing)` with
  `facing = GetPlayerFacing()`, tinted green to red by `angle - facing` (green when you face it). `HereBeDragons:GetWorldVector` is
  `atan2(-deltaX, deltaY)` normalised to counter-clockwise from north, the same convention (`Libs/HereBeDragons/HereBeDragons-2.0.lua:626-641`;
  `local atan2 = math.atan2`, the two-argument arc tangent of the game's Lua 5.1).
  It arrives at 12 yards, shows nothing when the step is on another continent, and does no road or obstacle routing at all (its only
  allowance is `WINDING = 1.35`, "a walk is longer than the straight line (hills, rivers, roads)", for travel time). It also sets the game's
  own waypoint (`C_Map.SetUserWaypoint` then `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`, `Core.lua:683-687`) so the game draws its pin,
  and uses `C_QuestLog.GetNextWaypoint` only for a step with no location of its own (`Nav.lua:145-150`).
- So the arrow is `bearing - facing` ("With you"). The camera direction is not available to addons (ForeverPlusPlus `docs/forever-api.md`,
  from `CameraDocumentation.lua`), so a view-relative arrow cannot be computed. 1.3.165 tried the screen position of the game's navigation
  target (`C_Navigation.GetFrame`, as Blizzard's `SuperTrackedFrame` does); in the user's Forever client the arrow then stayed in one place
  and only the distance changed, so it was removed. 1.3.167 removed the Turns button and the compass-fixed way too: the user asked for one way, not selectable.
- Neither example gives a road route or obstacle avoidance: the client has no walkability data (see the top of this file), so Route and
  Around obstacles can only use a route step the game gives for the quest (`/ubf arrow` shows whether it does).

## The user's choice (1.3.170): With the view

The user tried the three ways (1.3.169) and chose "With the view". Their saved `qarrow.debug` from 1.3.165: `viewX` 1130.3, `viewY` 1026.2 with the screen centre at 1052.1, 600.0 (UI units), so in Forever `C_Navigation.GetFrame():GetCenter()` does give the marker's screen position (here near the top of the view, the objective ahead). The turn is `-atan2(viewX - centreX, viewY - centreY)`. With no valid position the arrow now uses `bearing - GetPlayerFacing()` instead of the compass direction.

## Navigation research (2026-11-21): what the game and the examples give, and what had to be learned

Sources: `Blizzard_APIDocumentationGenerated` (Forever build), ForeverPlusPlus (MIT, `Project Support/.../ForeverPlusPlus`), ThePath 1.6.2 (GPL-3.0, `ThePath-1.6.2`), FarstriderLib and its Data package v1794960000 (GPL-3.0, `FarstriderLibData-v1794960000`), two Forever travel guides, and the user's own game through the `/ubf` scans (`tools/read_saved.py navData.<name>`).

**No road, terrain, water, collision, dock or entrance data for addons.**
- The map points of interest (`C_AreaPoiInfo.GetAreaPOIForMap` on all 60 maps): 16 in total (the six capital-city markers on the world and continent maps, four on the Darkspear Islands), `atlasName` always missing, no boat, zeppelin, skyship or tram. The only "transport-like" hit was Shipwreck Cove (a false positive).
- `C_EncounterJournal.GetDungeonEntrancesForMap`: empty on every map (the Encounter Journal is switched off in Forever: ForeverPlusPlus `docs/forever-api.md`, game rule `EncounterJournalDisabled`).
- `C_QuestLog.GetNextWaypoint` / `GetNextWaypointForMap` / `C_Navigation.GetNextWaypointForMap`: existed but answered nothing for the user's quest on its own map ("route step: none from the game").
- Camera direction: not available to addons (ForeverPlusPlus `docs/forever-api.md`). The screen position of the game's navigation target (`C_Navigation.GetFrame():GetCenter()`) is: the user's saved numbers showed it at (1130.3, 1026.2) with the screen centre at (1052.1, 600.0) while the objective was ahead. In 1.3.165 the arrow built on it seemed to "sit in place" because the objective stayed ahead, and because with no valid position it fell back to the compass direction; the user then chose "with the view" anyway.

**What the maps scan gave**: 60 maps with sizes in yards (Kalimdor 36799.8 x 24533.2, Eastern Kingdoms 35199.9 x 23466.6, zones 790 to 10133 yd wide), their parents and rectangles on the parent. World positions: `cx = -south_yd + c1`, `cy = -east_yd + c2` (least squares over the 23 Kalimdor zones: coefficients -1.000 and -0.000), so x is north and y is west; Orgrimmar to Durotar's middle is 1775 yd. The 1463 and 1464 maps (type 2, parent 0) are older duplicates of the continents.

**Flight masters** (`C_TaxiMap.GetTaxiNodesForMap`, any time, not only at a flight master): 76 distinct nodes on the two continent maps, each map listing both factions' nodes (faction 0 neutral 9, 1 Horde 33, 2 Alliance 34), atlas `TaxiNode_Alliance/Horde/Neutral`; one node is named `zzOLDPowderfuse Port, Riverglades`. The first scan stored `isUndiscovered` as `n.isUndiscovered and true or false`, which turned nil into false, so it could not say whether the game reports discovery; `FlightPaths.lua` keeps nil, true and false apart and trusts the flag only when some node says true. ThePath's finding for Forever: every node the flight map lists is discovered (`C_TaxiMap.GetAllTaxiNodes` at a master).

**The examples**
- ThePath: the trail is a straight line of dots; the arrow is `SetRotation(angle - GetPlayerFacing())`; zone crossings are learned from players (where the zone changes on foot) and shared; one hand-made water pair; a travel planner over walking, flights, hearth and eight Horde/neutral docks ("approximate dock positions"); it sets the game's waypoint (`C_Map.SetUserWaypoint` then `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`).
- ForeverPlusPlus: the same arrow; the quest point from `GetNextWaypoint` else `GetQuestsOnMap` up the map tree; a map pin layer built on a map data provider (`CreateFromMixins(MapCanvasDataProviderMixin)`, plain frames on `map:GetCanvas()`), which `FlightPaths.lua` follows.
- FarstriderLib (Dijkstra over a travel graph, `FindTrail`/`FindTrailTo`): edge types travel (a straight line times a detour factor), flight path, portal, boat, zeppelin, item, spell, tram; "isolated area" settings say whether two places can be reached directly. Its Forever ("Camelot") data has 16 connections: the Deeprun Tram (8), Menethil-Theramore (as Baradin Bay - Theramore - Menethil), Booty Bay-Ratchet and 8 mage portals; no zeppelins.
- The wiki pages for boats and zeppelins (warcraft.wiki.gg) give no dock coordinates.

**Therefore** the addon learns, and keeps everything in `DB.learned` (never expires, only grows): `Trail.lua`. Open question for the next reader: how `GetUnitSpeed("player")` and the map position behave on a boat or zeppelin in Forever (the ride detector assumes speed 0 while the position moves; the first play data showed `GetUnitSpeed` 0 with 1 to 3 yd of drift while standing, hence the 8 yd in 2 s rule).


## The line under the distance (1.3.178)

- `C_QuestLog.GetQuestObjectives(questID)` answers `objectives`, a table of `QuestObjectiveInfo`, and may return nothing
  (`D/QuestLogDocumentation.lua:476-490`, **C163**). A `QuestObjectiveInfo` carries `text` as a `string`, `type` as a
  `string`, `finished` as a `bool`, `numFulfilled` and `numRequired` as `number` (`D/QuestLogDocumentation.lua:1581-1589`,
  **C164**). `text` is the sentence the quest log shows, so an objective that is an action ("Ride the boat to ...") reads
  as one. The code takes objective number 1 always, whatever is finished (the author's rule).
- A font string does not wrap unless it is asked to: `SetWordWrap` takes a `bool` (`D/SimpleFontStringAPIDocumentation.lua:719-726`,
  **C166**) and `SetMaxLines` takes a `number` (**C165**). The note line is 300 px wide and is given `SetWordWrap(true)`, so a
  long objective wraps instead of running off the screen.
- With no quest followed the line writes nothing and is hidden; when the aim crosses to another continent the line names the
  ride (`Q.noteLine`, `crumb.kind` `ride`/`board`/`unknown`), because there the objective is the crossing itself.

## The numbers a fresh install starts with (1.3.178)

The author's own live saved settings (`WTF/Account/FAQJOO/SavedVariables/Ubermoc-Forever.lua:32006-32012`, **C159**) hold
qarrow `px` `56`, `opacity` `50`, `mode` `4`, `art` `4`, `size` `3`, `turn` `1`, and `fade.gbar.idle` `0`. Those are now the
defaults (`UF.SEED` in Core.lua and `Q.DEFAULTPX` / `Q.DEFAULTOPACITY` / `Q.DEFAULTPLACE` in QuestArrow.lua); before this
the code fell back to `px` `40` and `opacity` `100` (**C162**) and the seed gave `qarrow` only `on` = `true` (**C161**).
The place is the spot he dragged it to (`fx 0.4992`, `fy 0.2322`), not one of the six named places; a character with
nothing saved gets that place through `Q.place()`. Settings already saved for a character are left alone.
