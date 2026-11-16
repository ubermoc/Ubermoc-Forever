# Research: cinematic camera while talking to an NPC (2026-11-16)

Goal from the user: when talking to a quest giver or gossip NPC, the camera moves in like a short cutscene, and the
quest window stays **exactly Blizzard's own** (no re-skinned dialogue box).

## What exists (read, not copied)
`UbermocUI/Cinematic.lua` (594 lines, the user's own addon, "all rights reserved" header: the user is the author, so reuse is
his call). It never replaces the quest window. It only changes the world around it:
- **Trigger:** events `GOSSIP_SHOW`, `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE` (list continues past
  line 328 of the file); "talking" = `GossipFrame` or `QuestFrame` shown. Ends when both are hidden, on combat, after reload.
- **Camera:** `CameraZoomIn/Out` toward a goal read with `GetCameraZoom()`; `cameraFov` CVar eased to a lens value;
  `pitchlimit` console command to lower the camera; CVars `test_cameraTargetFocusInteractEnable`,
  `test_cameraTargetFocusInteractStrengthPitch/Yaw` turn the camera toward the NPC; `CameraKeepCharacterCentered` and
  `CameraReduceUnexpectedMovement` set to 0 while framed. Framings: NPC centred, side by side, over the shoulder.
- **Screen:** black bars and dark edges (plain textures on a full-screen frame), `UIParent:SetAlpha` fades the interface,
  and `SetIgnoreParentAlpha(true)` keeps `GossipFrame`, `QuestFrame`, tooltips and popups visible.
- **Sound/names:** music/ambience/SFX volume lowered, unit-name CVars switched off (those can't change in combat).
- **Safety:** every CVar is saved first in the saved variables and restored on end, so a reload mid-talk still restores it.
  The game's "experimental camera" confirmation (`EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED` on `UIParent`) is muted briefly
  around each CVar change.
- Other mods named by the user (Immersion, DialogueUI): not installed here. `Spoken` has `UI/DialogueUITheme.lua` but that is
  a voice/subtitle theme. Not read in depth; web look-up can be done if the user wants more ideas.

## Facts to confirm in the game (not verified)
- `test_cameraTargetFocusInteract*` CVars exist in Forever (UbermocUI uses them, so probably yes).
- `pitchlimit` via `ConsoleExec` works in Forever.
- Whether Blizzard's own source in this client has any interaction camera: grep of `blizzard-ui-source-forever` found only
  keybinding `CameraZoomIn` and `Blizzard_GamepadTargeting/TargetLogic.lua` (zoom by script), nothing for NPC talk.

## Risks
1. **Two addons doing the same thing.** If UbermocUI is loaded and its cinematic is on, both would fight over the camera and
   CVars. Ours must stand down when `UbermocUIAPI` exists (or give a choice).
2. **Taint:** `SetAlpha` on `UIParent` and `SetIgnoreParentAlpha` calls are method calls, not field writes, so low risk, but
   only touch Blizzard frames out of combat and never write fields on them (see `LUA-WOW-GUIDE.md` section 3).
3. **CVars left changed** after a crash: needs the same save-first/restore-on-login scheme.
4. Controller: while the cinematic is on, `GameNav` still owns the buttons; nothing else needs to change.

## Proposed minimal first version (one feature)
New file `Cinematic.lua` (after `GameNav`): on talk start, save CVars, ease camera in (zoom + face the NPC), black bars and
interface fade except the quest/gossip window, restore everything on end. Options page: on/off only at first. Defaults
conservative. Later steps (separate): framing choices, vignette, sound.
