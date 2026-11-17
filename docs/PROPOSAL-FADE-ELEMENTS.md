# Proposal: fading every part of the interface (2026-11-16)

Frame names below were read from Forever's own Blizzard source (`blizzard-ui-source-forever`); names that this game does not have are skipped at run time and
shown greyed on the page ("not available").

## 1. How parts that are glued to something else get separated
Opacity is multiplied down from a frame to everything inside it, so fading the main bar also fades its end caps. A part that has its own setting would be set to
**ignore its parent's opacity** (`SetIgnoreParentAlpha`, which exists for frames and textures) and get its own absolute opacity. A part with no setting keeps
following its parent, exactly as now. This needs one engine change: frame paths such as `MainActionBar.EndCaps.LeftEndCap` (like UbermocUI's `getFrame`).

## 2. The lists (each is one drop-down on the page; only one open at a time)
Counts are elements; the whole page needs a scrolling left column (about 100 rows).

**Main bar parts** (new, separate from the bar)
- Left end cap (the gryphon): `MainActionBar.EndCaps.LeftEndCap`
- Right end cap: `MainActionBar.EndCaps.RightEndCap`
- Bar border art: `MainActionBar.BorderArt`
- Page number and arrows: `MainActionBar.ActionBarPageNumber`
- The bar itself (everything else on it): `MainActionBar`

**Action bars:** Bar 2 `MultiBarBottomLeft`, Bar 3 `MultiBarBottomRight`, Bar 4 `MultiBarRight`, Bar 5 `MultiBarLeft`, Bars 6 to 8 `MultiBar5/6/7`, Stance bar,
Pet bar, Possess bar, Extra action button `ExtraActionBarFrame`, Zone ability `ExtraAbilityContainer`, Vehicle exit `MainMenuBarVehicleLeaveButton`, Totem bar
`MultiCastActionBarFrame`.

**Player frame parts:** whole `PlayerFrame`; portrait `PlayerFrame.PlayerFrameContainer.PlayerPortrait`; frame art `...PlayerFrameContainer.FrameTexture`;
health bar `PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer`; power bar `...ManaBarArea`; status icons (`...PlayerFrameContentContextual`).
**Target frame parts:** the same pattern under `TargetFrame` (portrait, frame art, name, health bar, mana bar, icons). Also: Target of target, Focus, Focus target,
Pet, Boss frames `BossTargetFrameContainer`, Party `PartyFrame`, Raid `CompactRaidFrameContainer`, Arena, Player cast bar, Pet cast bar.
**Class resources:** the combo, rune, holy power, soul shard, arcane charge, chi, essence, stagger, insanity, soul fragments, fury and ebon might bars, alternate power.

**Buffs and auras:** Buffs `BuffFrame`, Debuffs `DebuffFrame`, Deadly debuffs `DeadlyDebuffFrame`, External defensives `ExternalDefensivesFrame`.

**Minimap parts:** the whole `MinimapCluster`; background and border `MinimapCluster.Background`; zone name `MinimapCluster.ZoneTextButton`; tracking
`MinimapCluster.Tracking`; mail and crafting icons `MinimapCluster.IndicatorFrame`; zoom buttons `Minimap.ZoomIn/ZoomOut`; calendar `GameTimeFrame`; expansion button
`ExpansionLandingPageMinimapButton`; difficulty; coordinates; queue eye `QueueStatusButton`.

**Quests and objectives:** the whole tracker `ObjectiveTrackerFrame`; its sections (quests, campaign, world quests, bonus objectives, achievements, scenario,
professions recipes, monthly activities, tasks, widgets).

**Chat:** each chat window 1 to 4, the tabs (`GeneralDockManager`, `ChatFrameNTab`), the edit box, the buttons column (`ChatFrame1.buttonFrame`), quick join.

**Menus and bars:** Micro menu whole `MicroMenuContainer` and optionally each button (Character, Spellbook, Talents, Achievements, Quests, Guild, Group finder,
Collections, Adventure guide, Shop, Game menu, Help), Bag bar `BagsBar` (and its expand toggle), Experience and reputation bars (`MainStatusTrackingBarContainer`,
`SecondaryStatusTrackingBarContainer`).

**Alerts and text:** alert popups `AlertFrame`, zone name `ZoneTextFrame`, sub-zone `SubZoneTextFrame`, boss banner, event toasts, raid warnings and boss emotes,
talking head, red error messages, loss of control, spell proc glows `SpellActivationOverlayFrame`, floating combat text `CombatText`, timers `TimerTracker`, the red
low-health screen edge `LowHealthFrame`, ready check, group loot history.

**Widgets and overlays:** UI widgets (top centre, below minimap, power bar, centre screen), durability, vehicle seats, frame rate, encounter bar, damage meter,
cooldown viewers (essential, utility, tracked buffs and bars), personal resource display, nameplates (enemy, friendly; they are not under one frame, so these two
work through the nameplate list).

## 3. Page changes this needs
- The left column becomes a scrolling list (mouse wheel, and it scrolls itself to the highlighted button when the D-pad moves).
- Two conveniences I suggest: **Apply to the whole list** (copy this element's four settings to every element in the open list) and **Copy / Paste** between
  elements. Optional.
- The page shows "not available" for any frame this game does not have.

## 4. Risks
- Fading a frame that the game itself fades or hides (cast bars, nameplates, alerts) can fight it; the engine re-applies twice a second.
- Some parts (the portrait, frame art) are textures, not frames: textures can be faded the same way, but a game update that renames a part makes that row show
  "not available" until the name is fixed.
- Names written for the retail layout that Forever's source does not have are skipped, not guessed.
