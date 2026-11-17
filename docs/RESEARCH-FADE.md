# Research: fading interface elements by situation (2026-11-16)

Source read: `UbermocUI/Main.lua` ("Fade Rules" page, `ELEMENTS`, `FADE_CATS`, `PRIORITY`, the fade driver). Not copied; the engine here is a smaller one.

## What UbermocUI does
- Situations ("states") in a priority order; an element uses the first ACTIVE state it has a value for, else it is left alone. There are ten states there
  (talking to an NPC, in combat, health not full, mounted/traveling (includes `UnitOnTaxi("player")`), moving, in an instance, in a group, has a target,
  rested area, idle).
- Each element has a list of frame names (resolved at run time, missing ones skipped) and an opacity 0 to 1 per state, or "hide".
- One driver frame eases each element's opacity toward its goal and calls `SetAlpha` on the frames. Only frames that need it are touched; it re-applies
  about every half second because the game resets some frames.
- The settings list is grouped under headings; only one group is open at a time.

## What was asked for here
Separate from cinematic mode. Four states: talking to an NPC (the first one; the word was garbled), in combat, out of combat, on a flight path.
Each 0 to 100, or hidden for good. Elements grouped in drop-down lists, one open at a time, on their own options page. First elements: unit frames,
action bars, minimap and trackers, chat and menus.

## Frame names checked against Forever's Blizzard source (`blizzard-ui-source-forever`)
Found: MinimapCluster, ObjectiveTrackerFrame, MainActionBar, MultiBarBottomLeft/BottomRight/Right/Left, MultiBar5/6/7, StanceBar, PetActionBar,
PossessActionBar, MicroMenuContainer, BagsBar (Camelot file), StatusTrackingBarManager, ExtraAbilityContainer, PlayerFrame, PetFrame, TargetFrame,
FocusFrame, PartyFrame, CompactRaidFrameContainer, BuffFrame, DebuffFrame, PlayerCastingBarFrame, ChatFrame1, QueueStatusButton.
Not found in the XML: TargetFrameToT (target of target, created another way), MainMenuBar. Missing frames are skipped at run time.
The game's own APIs: `UnitOnTaxi("player")`, `UnitAffectingCombat("player")`, frames' `SetAlpha`. `SetAlpha` is not protected, so it also works in combat.

## Risks
- Both UbermocUI's fading and ours would set the same frames' opacity: use one of them.
- Cinematic mode also sets some frames' opacity for a talk (and puts it back). They can briefly disagree during a talk.
- "Hide" here means opacity 0; a hidden frame can still take clicks (making a protected frame ignore the mouse is not allowed in combat).
