# Steward service selection

Written 2026-10-28. Stable brief; execution evidence lives in PROGRESS.md.

## Goal

The existing Steward stands in Camp, holding a modeled parchment with a world-space dish list. Use blends the chef's CkCamera toward the parchment and holds until a committed selection or Back. Only an authoritative, valid party selection opens the physical Spire gate. Existing host, guest browsing, departure and return contracts remain authoritative.

## Constraints

- Mission metadata: service definitions/catalog. Party selection: existing replicated Camp GameState. No second mission state.
- Presentation assets and tuners: grouped assembly config; widget trees authored as WBP assets; behavior in existing control/presenter paths; gate physics through utils_gate.
- Reuse the existing Steward skeleton; keep original mesh/skeleton hashes unchanged. Camp may use the separately corrected mesh variant for proven garment weight leakage. Add a separate Blender-authored present loop and procedural parchment; preserve existing idle and Devour behavior outside camp.
- New camera behavior uses CkCamera layers and utils_player_viewpoint, following the existing station layer.
- Spire visuals use existing kit instances and persistent collision proxies at the documented camp seam.
- Scope saves to owned assets and Camp; preserve existing submodule dirt. Local logical commits requested; no push.
- Editor ensure display policy StreamerMode (2). All build/automation via CkAuto/UnrealToolbox.exe.

## Acceptance

1. Camp contains Steward, readable parchment, existing Spire connector, and closed physical gate.
2. Real Use opens scroll; camera blends and remains; wheel/navigation scroll and select work; Back restores gameplay input/view.
3. Browse/back leaves party state and gate unchanged. Accepted host selection opens gate; guests cannot commit. Late joins reconcile from replicated party state.
4. Departure uses the selected destination. Returning from a mission to hosted Camp restores the committed service and open gate. ReturnToMenu resets the standalone party and closes the gate.
5. Fresh focused automation, startup log review, actual PIE observations, saved asset validation and visual captures are reported separately.

## Current implementation contract

- Four dish IDs (DillBroth, PanSearedRoots, MushroomPie, ProperDinner) target canonical `/Game/Mars/Maps/Warrens_Mars_MAP`. Sandbox and BrokenCistern remain compatible catalog entries.
- `UMars_StewardService_Config` groups parchment, view and widget tuning, validates the complete presentation, and explicitly initializes nested asset defaults. Reading rectangle is 80 x 90 cm; parchment root offset is `(55,0,175)` cm. The separate holding animation is six seconds / 181 frames on the existing skeleton.
- Contracts opens through the existing local interaction target/controller/presenter. The CkCamera CampService layer targets a retained per-station node, while CampMenu holds look. Back releases only this holder/layer; Devour takeover closes the board and removes the menu layer immediately. The local chef hands/presentation are hidden while reading and restored on close.
- Gate projection reads the atomic replicated CampPartyState and catalog; only a valid committed service with destination opens it. Preview is local, never mission state. The placeable gate uses existing Gate/Mover/Trigger logic, UE mesh collision for the chef's CharacterMovement and explicit Jolt boxes on separate entities for loose objects; default opening is 400 x 360 cm, unit root scale.
- Hearthscrew visuals and collision are grouped persistent HISM actors in Camp. No Level Instance remains in this integration: even a noncolliding LI triggered Jolt transient-level identity validation. Source Spire kit levels/assets remain unchanged.
- PIE may adopt an actual listen/client Camp session only through the guarded editor-session path. Real game host/commit/travel authority remains the existing LAN flow and GameMode.

Current status and all acceptance evidence are maintained in PROGRESS.md. Revision3 adds CampMenu prompt/outline suppression, the taller800x900 world widget, forward floor drape, and a single gate in the original camp arch. Read the latest evidence before claiming completion.

## References

Script/WorldSettings/Camp/Mars_Camp_GameMode.as; Script/UI/Camp/Mars_CampUiPresenter.as; Script/PlayerCharacter/HFSM/Mars_PlayerCharacter_Hfsm_Operating.as; Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as; Tools/Blender/mars_steward/build_steward.py; Tools/SpireConnectorKit/unreal_scenes.py.
