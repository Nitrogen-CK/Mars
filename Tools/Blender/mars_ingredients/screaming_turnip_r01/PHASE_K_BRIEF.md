# Phase K brief - the stretch becomes an Unreal tuner: a runtime crown driver through an anim blueprint, the clips keep only the pose

You are an Opus executor for one part of Phase K. Read first: `PHASE_J_BRIEF.md` and the Phase J sections at the end of
`PROGRESS.md` (Parts 1-1e, 2-2b, 3-3f and the two Fable audit addenda: what the pull is today and every number measured),
then the files your part names. Project rules are binding: `CLAUDE.md` ("Mars gameplay script conventions": three layers,
request doctrine, max 3 params, Validate mixins on specs, TOptional over sentinels, enums over bools, grouped tuners),
`Plugins/CkFoundation/Script/ARCHITECTURE.md`. The maintainer's words for this phase (2026-11-09): "Go with the best, most
scalable, robust approach. No hacks or shortcuts. If something is missing or needs to be updated, do it. Follow the project
guidelines on how the data, tuners and visuals are divided and grouped. Always verify, don't guess."

## Why

Phase J made the pull a walk-away stretch, but the stretch DISTANCE is authored into `SRC_Tug` (the crown bone's travel)
and the bed's Control `WalkCm` must equal it, so every distance change (36 -> 72 -> 144 cm) was a Blender round plus a
reimport. The maintainer asked for the amount to be tunable in Unreal. The crown is one bone; the stems and leaves are
skinned to it; the HarvestGrip sockets ride it. So the distance can be a runtime bone offset and the clips can keep only
what is pose: the crown pitch, the trailing leaves, the bulb tilt.

## Decisions (Fable; verified against the code and the tools)

### D-K1 The established pattern: an AngelScript anim instance + an anim blueprint built by Monolith

Mars drives bones at runtime through an AngelScript `UAnimInstance` subclass holding plain data fields and an anim
blueprint asset parented to it whose graph applies them: `Script/PlayerCharacter/Chef/Mars_Chef_AnimInstance.as` +
`ABP_Chef` (TwoBoneIK + Transform (Modify) Bone read `HandLocation_*`), `ABP_FPHands`, and the Cellar Bat's
`Mars_CellarBat_AnimInstance.as` + `CellarBat_R01_Final_Mars_ABP`, which the campaign BUILT through Monolith's
`animation_query` actions from a python JSON-RPC client (`Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py`:
read its header for the calls that worked, the rebuild-to-a-fresh-name rule and the dead ends). Monolith's write actions
(`Plugins/Monolith/Source/MonolithAnimation/Private/MonolithAbpWriteActions.cpp`) place `ModifyBone` (`bone_to_modify`,
`expose_pins`), any `UAnimGraphNode_Base` subclass by `node_class` (the Sequence Evaluator), `LocalToComponentSpace` /
`ComponentToLocalSpace`, bind pins to instance variables (`set_anim_node_pin_binding`), set inner node properties
(`set_anim_graph_node_property`), wire pins (`connect_anim_graph_pins`), `set_output_pose_source`, `auto_layout`; use
`describe_query action_schema` for each action's exact params before calling it. CkProceduralAnimation drives procedural
rigs of scene nodes (the crawler's leg parts), not skeletal bones: not the tool here. A ref-pose override, a poseable mesh,
or a hand-built asset the tooling cannot rebuild are the shortcuts not to take.

### D-K2 The layers and where each number lives

- **Kernel (Control):** unchanged. The bed's Walk control gets `WalkCm` from the bed's tuner.
- **Assembly (the bed, `Mars_ScreamingTurnipBed_EntityScript.as`):** ONE grouped spawn tuner replaces the loose
  `GripSeconds` param and the private spring/cancel/turn constants:
  ```angelscript
  struct FMars_ScreamingTurnipBed_StretchSpec   { float32 TravelCm = 146.2f; float32 LiftCm = 20.0f; }
  struct FMars_ScreamingTurnipBed_SpringSpec    { float32 Stiffness = 400.0f; float32 Damping = 40.0f; float32 EngageAlpha = 0.97f; }
  struct FMars_ScreamingTurnipBed_TimingSpec    { float32 GripSeconds = 0.4f; float32 CancelSecondsFromFullStrain = 0.7f; float32 TurnDegreesPerSecond = 540.0f; }
  struct FMars_ScreamingTurnipBed_PullSpec      { Stretch; Spring; Timing; }   // UPROPERTY(ExposeOnSpawn) FMars_ScreamingTurnipBed_PullSpec Pull;
  ```
  Each struct carries a full positional constructor (the spawn-params generator emits a non-default value as the positional
  call; see `FMars_Control_Manipulation_Spec`) and `FMars_ScreamingTurnipBed_PullSpec` has a `mixin FMars_Validation Validate()`
  (travel > 0 and finite, lift finite, stiffness > 0, damping >= 0, engage alpha in (0, 1], seconds > 0, turn rate > 0) that
  `DoConstruct` wraps in `ck::EnsureIfNot` and, on failure, destroys the entity (the Forage/Control pattern already in the
  bed). `WalkCm = Pull.Stretch.TravelCm`. `constants_screaming_turnip_assets::k_StretchTravelCm` is deleted (its meaning,
  "the clip's authored travel", no longer exists); the ScreamingTurnip test rig reads the bed's `Pull.Stretch.TravelCm`
  (spawn the bed with an explicit Pull so the test does not depend on a default). `k_MinSpannedStrain` stays a constant
  (not a tuner). Where the structs live: beside the bed in `Script/WorldObjects/Forage/` (a station-style assembly spec),
  not in `Script/ECS/`.
- **Assembly, per tick (the bed's follow tick):** the stretch alpha is: the Control's manipulation alpha while gripped;
  `1 - Get_PlayedAlpha()` while `SRC_Cancel` plays (the cancel is the Tug's mirror); 0 otherwise. The bed passes
  `FMars_ScreamingTurnip_Stretch(Alpha, Pull.Stretch.TravelCm, Pull.Stretch.LiftCm)` to the presentation each tick
  (`Set_Stretch`), scrubs `SRC_Tug` to the alpha as today, turns toward the puller as today. `OnForageReleased` sets the
  stretch to 0 before hiding the mesh.
- **Presentation (`Mars_ScreamingTurnipPresentationComponent.as`):** owns the mapping from the stretch to the bone:
  `CrownOffset = (-Alpha * TravelCm, 0, Alpha * LiftCm)` in the mesh's own (component) space - the lean is toward the
  mesh's -X, the Use side, as the clips are authored - and the clock for every clip. It plays through the anim blueprint
  (`AnimationMode = AnimationBlueprint`, `SetAnimInstanceClass(constants_screaming_turnip_assets::TryLoad_AnimClass())`),
  writing the instance's fields each tick: `Sequence`, `ClipTime`, `CrownOffset`. The component is the single clock:
  `_Time += dt * Rate`, Loop wraps, HoldLastFrame clamps, `SpanSeconds` sets the rate, `StartAlpha` seeds `_Time`,
  `Scrub_Clip` sets `_Time` and rate 0; `Get_PlayedAlpha` / `Get_HasPlayedThrough` read `_Time`, never the engine's
  single node. `Play_ClipChain` (no callers) is deleted. The public surface otherwise stays (`Play_Clip`, `Scrub_Clip`,
  `Set_Stretch`, `Get_PlayingClip`, `Get_PlayedAlpha`, `Get_HasMesh`, `Set_Turnip`, `Refresh_FromKernel`). A missing anim
  class warns once and the mesh holds its bind pose (the bat's rule); there is no single-node fallback path (two playback
  paths is the hack). The component also widens its bounds for the stretch (`BoundsScale` from TravelCm against the mesh's
  bounds, set in `Set_Stretch` when the travel changes), so the leaves draw when the bulb is off-screen whatever the tuner.
- **Anim instance (`Script/Items/Presentation/Mars_ScreamingTurnip_AnimInstance.as`, new):**
  `class UMars_ScreamingTurnip_AnimInstance : UAnimInstance` with `UPROPERTY(BlueprintReadOnly, NotEditable)`
  `UAnimSequenceBase Sequence`, `float32 ClipTime`, `FVector CrownOffset` (component space, cm). Written only by the
  presentation component; its `BlueprintUpdateAnimation` does nothing. Header comment names the ABP and the writer.
- **Anim blueprint (content, `/Game/ArtCandidates/ScreamingTurnip/R01/Animation/ScreamingTurnip_R01_Mars_ABP`):** parent
  `/Script/Angelscript.Mars_ScreamingTurnip_AnimInstance`, skeleton `ScreamingTurnip_R01_Mars_SKEL`. AnimGraph:
  `SequenceEvaluator` (node_class `/Script/AnimGraph.AnimGraphNode_SequenceEvaluator`; pins `Sequence` <- `Sequence`,
  `ExplicitTime` <- `ClipTime`; `bShouldLoop` false - the component wraps; reinitialization none) -> `LocalToComponentSpace`
  -> `ModifyBone` (`bone_to_modify` `crown`; `TranslationMode` Add, `TranslationSpace` ComponentSpace, Rotation and Scale
  Ignore, `Alpha` 1; pin `Translation` <- `CrownOffset`) -> `ComponentToLocalSpace` -> Output Pose. Built by a NEW script
  `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_animbp_ue.py` patterned on the bat builder (JSON-RPC
  client outside the editor; `editor_query run_python` for compile and the per-asset save; `--readback-only`; prints
  `TURNIP_ABP_OK / _FAIL`; a rebuild never edits in place - a fresh `_vN` name, and the consumer constant is updated), with
  a readback that proves the graph (`get_nodes`, `get_anim_node_pin_bindings`, `get_anim_graph_output_connection`) and the
  compile (`list_errored_blueprints` empty for it). `constants_screaming_turnip_assets` gains `AnimClass()` (soft class path
  to the `_C`) and `TryLoad_AnimClass()`.
- **Blender (clips only; the mesh and weights do not change):** `STRAIN` and `TUG_MID` set `cr_dx = 0`, `cr_dz = 0`
  (keep `cr_y`, the leaves, the bulb tilt); `SRC_Cancel` stays the Tug's mirror; `SRC_Release` keeps its ease. Because the
  travel now happens at runtime, the deformation audits must see it: add an `--inject-stretch T,L` mode to the animate
  audit that adds the runtime crown offset `(-T * a, 0, L * a)` (design cm = UE / 3) per frame of `SRC_Tug` (a = the
  frame's fraction of 15) and `SRC_Cancel` (a = 1 - fraction of 7) before the intersection / stem_gap / neck checks, and
  run it for (T, L) in {(36, 5), (74, 10), (146, 20), (220, 30)} UE cm: every gate must hold at 146/20 (the shipped
  default); report where the first failure appears above it, so the tuner's safe range is a number in the manifest
  (`gameplay_numbers.stretch_runtime_safe_travel_cm`). Sheets of `SRC_Tug` with the injected 146/20 offset. Diff proof:
  only the three SRC clips change; the exported `expected_anims.json` for `SRC_Tug` now shows the crown head fixed in x.
  Manifest: `k_StretchTravelCm` becomes `k_StretchTravelCm_default` with a note that the travel is a bed tuner.

### D-K3 Known, accepted

- The HarvestGrip sockets swing about 2.2 cm past the crown at full pitch (authored), so the sockets travel `TravelCm + ~2`
  while the player walks `TravelCm`: the gloves ride the sockets, the arms give 2 cm. Documented at `WalkCm`.
- The clip's `SRC_Tug` pitch/leaf ease is scrubbed to the alpha while the offset is linear in alpha: the leaves lead or
  trail the crown a little mid-pull. Acceptable; say what the sheet shows.
- Headless lanes do not load the mesh or the ABP (they never did); the presentation stays untested by lanes. The PIE part is
  the proof.

## Part 1 - Blender (an executor; writes only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/`)

Back up the blend to `source/ScreamingTurnip_R01_phaseJ.blend` first. Then D-K2's Blender bullet in full: poses, the
`--inject-stretch` audit mode and its four runs, re-animate, re-export (clips; the SK export may run but must be
byte-identical in intent - prove with `compare_rebuild`), round trip, diff proof, manifest, sheets, `PROGRESS.md` Phase K
Part 1 (re-read before appending; append in one write). Stop and report: the injected-stretch audit table per (T, L), the
safe travel, what the sheets show.

## Part 2 - Script (an executor; writes only under `Script/` and the record file; no Generated/*, no tags ini, no git)

D-K2's bed, presentation, anim instance and constants bullets. Tests: the ScreamingTurnip rig spawns the bed with an
explicit `Pull` and reads `Pull.Stretch.TravelCm`; new `Mars_AutoTest_ScreamingTurnipBed_PullSpecValidateRejectsBadTuners`
(one valid, and one rejection per rule; the bed ensures and destroys itself on an invalid Pull - test it with the ensure
expected, as the Control spec test does) and `Mars_AutoTest_ScreamingTurnipBed_WalkDistanceIsTheStretchTravel` (the bed's
Control `WalkCm == Pull.Stretch.TravelCm` for a non-default travel). Lanes: `ScreamingTurnip`, `Control`, `Forage`
(`--test --no-live --discover-fresh`, one at a time, in the background; read the real `Passed:/Failed:` and the known-reds
block). The live editor is open and hot-compiles your edits; that is expected. `PROGRESS.md` Phase K Part 2. Stop and
report with the lane numbers and the exact anim-instance field names the ABP must bind.

## Part 3 - ABP build, clip reimport, PIE (an executor; after Fable's go on Parts 1 and 2)

1. Preflight as Phase C2 / J (PIE off, nothing foreign dirty, Mars.log: the Part 2 scripts compiled, no pending Full
   Reload). Build the ABP with the new builder (D-K2), readback, compile clean, save that asset only. Record the exact
   Monolith calls that worked (as the bat builder's header does) and any dead end.
2. Reimport `SRC_Tug`, `SRC_Cancel`, `SRC_Release` (clips stage; readback: `SRC_Tug` crown head at f15 has x within 0.05 of
   f0's; counts 15/7/6; nothing else changed). No SK reimport unless Part 1 says the mesh changed.
3. The review room: `Mars.ScreamingTurnip.BuildReviewRoom` (`Script/Editor/Mars_ScreamingTurnip_MapBuilder.as`) must let
   the two beds carry different stretch travels so the tuner is proven without Blender - Part 2 adds optional args
   (`BuildReviewRoom <bed1 travel> <bed2 travel>`, default both 146.2) to the editor command; Part 3 rebuilds the room with
   `74 146.2`. The review map is the campaign's and may be written.
4. PIE run-12 from the 110 cm stand, both beds: bed 1 (74): the sockets travel 74 +- 3 cm over the pull and the root pops
   at 74 cm walked (+ the spring's lag at 30 cm/s); bed 2 (146.2): as run-11. Both: the crown head's x at full strain is
   `-TravelCm` within 2 cm (sample the `crown` bone or the HarvestGrip sockets), the leaves and pitch still trail, the gloves
   ride the sockets (0.000 cm to the previous tick's socket), the ring fills, a let-go on bed 2 cancels from the strain
   with the offset shrinking in step with the clip (no jump > 1.5 cm at the switch), charge kept, second pull pops,
   `was_recently_rendered` true with the bulb off-screen at full strain on bed 2, morph curves drive (a Screaming root's
   mouth still moves after the pull: pick the pulled root up and wait for a scream, capture it), 0 ensures (range quoted),
   nothing dirty outside the owned folder and the review map, Sandbox untouched. Captures: first-person grip / mid / full
   strain on each bed, a side view of each at full strain side by side, the cancel, the scream.
5. `PROGRESS.md` Phase K Part 3 and `VERIFICATION.md` K-rows.

## Hard rules

Every Blender script prints `TURNIP_OK / TURNIP_FAIL`; every builder prints `TURNIP_ABP_OK / _FAIL`; read the real line and
the exit code. Build/test only through `./CkAuto/UnrealToolbox.exe --project=D:/Repositories/CkRepos/Orion/Mars.uproject`.
No git. No deleting assets or files (a rebuild goes to a fresh name). Never minimize the editor; never `unload_packages`;
never reload a loaded Blueprint; never Save All. Final message per part: files, rerun commands, the numbers, which sheets or
captures to look at, what remains unverified, every claim confirmed (evidence) or inferred.
