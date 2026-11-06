# Phase D brief - Screaming Turnip runtime: kernel, item, presentation adapter, planted source, tests

You are the Opus executor for Phase D (the gameplay vertical slice) of the Screaming Turnip R01 campaign. Phase A/B/C
(Blender model, clips, Unreal import) run in parallel and are NOT yours; until they land you use placeholder assets
(see "Assets" below). Read first: `PROGRESS.md` beside this file (scope rulings, decisions D-1..D-5, Phase 1 facts),
`docs/art/screaming-turnip-production-r01/DESIGN_TECH_SPEC.md` sections 5, 6, 7 (state model, item/source composition,
feature/events) and 11 (acceptance), `ASSET_MANIFEST.json` (`timing` block). Then the project rules:
`CLAUDE.md` at the root (Mars gameplay script conventions: feature kernels, request doctrine, three station layers,
`Add(Handle, Spec)`, `Validate()` mixin, ids are tags, TOptional over sentinels),
`Plugins/CkFoundation/Script/ARCHITECTURE.md`, and `CkAuto/.claude/skills/build-test/SKILL.md` (test-only path beside
the open editor + quiescence protocol; the editor IS open this session).

Scope ruling that overrides the spec: **RootMaw hearing is out.** No file under `Script/ECS/RootMaw/` is touched, no
noise adapter, no occlusion trace, no listener. The kernel still broadcasts `OnScreamCommitted` (below).

## Code you must read before designing (file:line from the survey; verify, lines may have drifted)

- `Script/WorldObjects/Items/Mars_WorldItem_EntityScript.as` - `DoConstruct` (:76), private `AddVisual` (:276, always a
  `UStaticMeshComponent` named `WorldItem_Mesh`), `AddBody` (:306, body shape comes FROM the presentation's static mesh:
  `FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::StaticMeshAsset)`, `Set_ShapeScale(MeshScale)`), `AddPickup` (:331),
  `Compose_WorldItem` (:230), hooks `DoOnVisualMeshAdded`, `Get_PickupFocusPriority`, `DoGet_CanStowSelf`.
- `Script/WorldObjects/Items/Mars_Cookbook_EntityScript.as` + `Script/Items/Mars_Item_Cookbook.as` +
  `Script/Items/Presentation/Mars_CookbookPresentationComponent.as` - THE template: persistent world item, static
  proxy hidden in `DoOnVisualMeshAdded`, a `USkeletalMeshComponent` subclass (AnimationSingleNode, `PlayAnimation`,
  `Request_EnableTransformPush` so it follows the held scene node, component tick via processor), `OnMountChanged`
  binding, `DoEndPlay` unbinds then Super.
- `Script/ECS/WorldItem/Mars_WorldItem_Feature.as` (mounts `World/Carried/Held`; fragments `PendingLaunch`,
  `PendingMount`, `Arrival`, `PendingRelease`; signals `OnMountChanged(item, prev, new)`, `OnMountSettled(item, mount,
  carrier)` - note `OnMountSettled(World)` fires AT RELEASE TIME before any flight, and `Get_IsSettled()` is mount
  bookkeeping only, true for an item in flight), `Mars_WorldItem_Utils.as` (`Get_Mount`, `Get_Carrier`, `Get_Body`,
  `Get_Item`, `Get_IsSettled` :569, `Commit_World` :195, bind mixins :635-669).
- `Script/ECS/HeldItemUse/Mars_HeldItemUse_Processor_Requests.as:155` (throw/drop -> `WorldItem.Request_Release`).
- `Plugins/CkFoundation/Script/Generated/utils_jolt_body.as` - what exists: `Get_LinearVelocity`, `Get_SleepState`
  (`Awake/Asleep`; kinematic reads Awake), `Get_MotionType`, contact signals `BindTo_OnJoltBodyContactAdded /
  Persisted / Removed` (persisted needs `Set_PersistContacts(Enable)` on the body spec), payload `Get_OtherEntity`
  (INVALID for the baked static world), `Get_OtherIsSensor`, `Get_RelativeNormalSpeed`, `OnJoltBodySleepStateChanged`.
  What does NOT exist: angular velocity, per-body IsActive, body ground/support state.
- Settle precedents: `Script/ECS/Platter/Mars_Platter_Processor_Settle.as:150-190` (drift watchdog or Asleep),
  `Script/ECS/Resting/` (contact-based resting on target entities), `Script/ECS/Fry/Mars_Fry_Utils.as:35` (`Get_IsStill`).
- Forage: `Script/ECS/Forage/Mars_Forage_{Feature,Utils,Processor_Requests}.as` (`Request_Release(Reason)`,
  `EMars_Forage_ReleaseReason::Plucked` exists and is unused - use it; `OnReleased(forage, worldItem, reason)` with the
  item still under construction; `OnReleaseRefused`; `OnExhausted`; `Exhaustion::Persists` + 1 charge = one-shot bed).
  Source base `Script/WorldObjects/Forage/Mars_ForageSource_EntityScript.as` (`SetYieldVisible` casts to
  `UStaticMeshComponent` - do not rely on it for the skeletal planted visual; own your visibility).
- Use interaction on a world object: `Script/WorldObjects/Mechanisms/Mars_HandWheel_EntityScript.as` +
  `Script/ECS/Control/Mars_Control_Utils.as:77` (`Make_InteractTarget`: Timed policy, `Set_InteractionDuration`,
  `RequiresFreeHands = true` = unarmed, `ReachKind Hold`), `Script/WorldObjects/Mars_TestLamp.as:60-129` (minimal
  target + custom state/task), `Script/ECS/Interactable/Mars_Interactable_Feature.as` (`FMars_Interactable_TargetEntry`,
  `Work AfterCompletion` + Timed = cancelled when the press ends), `Mars_Interactable_Utils.as:474`
  (`BindTo_OnInteractionFinished(channel, delegate(interactable, interaction, SucceededFailed))`).
- Item defs: `Script/Items/Mars_Item_Ingredients.as` (Root at :21 stays untouched), `Mars_Item_Builders.as:55`
  (`Add_BlockoutTraits` adds Presentation + a default `UMars_ItemTrait_Throwable`),
  `Script/Items/Traits/Mars_ItemTrait_Presentation.as` (Visual = static mesh only; Grip Handedness/Layout/Shape; Mounting
  Persistence/CarryPoint/HeldOffset/ArriveSeconds; WorldItem.ScriptClass).
- FPHands grips read sockets `Grip_L`/`Grip_R` and hold faces from the UStaticMesh (`Script/ECS/FPHands/
  Mars_FPHands_Grips.as:371, :645-670`): that is why the static proxy stays.
- Tests: `Script/Tests/Forage/Mars_AutoTestRig_Forage.as` + `Mars_AutoTest_Forage_ReleasesPerRequestThenExhausts.as`,
  `Script/Tests/WorldItem/Mars_AutoTestRig_PickupByPress.as` (carrier with hands + hotbar, `Spawn_StaticSlab`, throw via
  `_Use.Request_Throw`, UseKey helper, focus/offer/press), `Script/Tests/Cookbook/` (skeletal presentation item tests),
  `Script/Tests/Common/Mars_AutoTestRig_Carrier.as`. Registration is generated (`Script/Generated/Mars_AutoTestActors.as`
  is rewritten by the live editor; never hand-edit it, never commit it). Map: `Mars_AutoTestMapConfig.as`.
- A recent small kernel to mirror for file layout and processor declarations: `Script/ECS/Resting/` (Feature with
  `Validate()` mixin, `Processor_Setup` on a NeedsSetup tag, `Processor_Requests` `_MarkedDirtyBy` the Requests fragment,
  `Processor_Tick` `_RunAfter` HandleRequests). Typed handle: `asset Mars_ScreamingTurnipHandle of
  UCkDynamic_HandleDefinition` + a hand-added entry in `Script/Generated/DynamicHandleTypes.json` (copy the `Bat` entry
  shape; the live editor may self-heal the same entry - keep exactly one).

## Deliverables

### D1 - kernel `Script/ECS/ScreamingTurnip/` (new files only)

`Mars_ScreamingTurnip_Feature.as`, `_Utils.as`, `_Processor_Setup.as` (if needed), `_Processor_Requests.as`,
`_Processor_Tick.as`. Typed handle `FCk_Handle_ScreamingTurnip`, marker `FMars_Feature_ScreamingTurnip`,
`utils_screaming_turnip` namespace; `Add(Handle, FMars_ScreamingTurnip_Spec)` wrapped in `ck::EnsureIfNot(Spec.Validate())`.

Spec (sub-structs, each with a `Validate()` mixin; all defaults from `ASSET_MANIFEST.json`):
- `FMars_ScreamingTurnip_Vocal { AnticipateSeconds 0.3; InhaleSeconds 1.2; ScreamSeconds 0.6; RecoverSeconds 1.0;
  CooldownSeconds 8.0 }` (cooldown measured from the scream COMMIT; an uninterrupted start-to-start period is
  Cooldown + Anticipate + Inhale = 9.5 s; never add ScreamSeconds again).
- `FMars_ScreamingTurnip_Settlement { EnterLinearCmPerSec 30; EnterAngularDegPerSec 20; EnterDwellSeconds 0.35;
  ExitLinearCmPerSec 100; ExitAngularDegPerSec 60; ExitDwellSeconds 0.15; SupportGraceSeconds 0.2 }`.
- `FMars_ScreamingTurnip_Parts { FCk_Handle_WorldItem WorldItem; }` (the persistent world item whose mount and body
  the kernel reads; `Validate` requires it valid).

Fragments (only this feature's processors write them):
- `FMars_Fragment_ScreamingTurnip_Params { Spec }`.
- `FMars_Fragment_ScreamingTurnip { Placement; Phase; float32 Clock (monotonic kernel time, accumulated from
  InDeltaT); float32 PhaseStartedAt; float32 WarningElapsed; TOptional<float32> LastScreamCommittedAt; int32
  ScreamSequence (0 = none yet); FVector LastWorldPosition; }`.
- `FMars_Fragment_ScreamingTurnip_Settle { float32 EnterDwell; float32 ExitDwell; TOptional<float32> LastSupportAt;
  TOptional<FQuat> PrevRotation; TOptional<float32> PrevSampleAt; float32 AngularDegPerSec; }` (sampling scratch).
- `FMars_Fragment_ScreamingTurnip_Signals` (lazy, broadcast only `if (Has_Fragment(Signals))`).
- `FMars_Fragment_ScreamingTurnip_Requests` with `TArray<FMars_Request_ScreamingTurnip_Suspend>` (placeholder field;
  used by the owning entity script on teardown / when it must silence the voice) - keep the request surface minimal;
  placement is DERIVED by the tick from WorldItem + body, not requested from outside.

Enums: `EMars_ScreamingTurnip_Placement { Transfer, Held, Loose, LooseSettled, Protected }` and
`EMars_ScreamingTurnip_Phase { Dormant, Anticipate, Inhale, Scream, Recover, RecoveryIdle }`. (Spec's Airborne and
LooseMoving are merged into `Loose` for gameplay; the presentation may tell them apart from the support sample via a
`Get_HasSupport` mixin.)

Placement derivation (every tick, in `Processor_Tick`, before the vocal advance):
- WorldItem mount `Held` and `Get_IsSettled()` -> `Held`; mount `Held`/`Carried` but not settled (PendingMount /
  Arrival / PendingRelease) -> `Transfer`; mount `Carried` settled -> `Protected`; mount `World` -> `Loose` or
  `LooseSettled` from the physical sampler.
- Physical sampler (mount World only): linear speed from `Get_LinearVelocity`; angular speed from the root transform's
  rotation delta between samples (deg/s; never radians compared to the deg thresholds); support = a non-sensor
  contact added/persisted within `SupportGraceSeconds` whose other entity is invalid (static world) or a non-dynamic
  body, OR `Get_SleepState == Asleep`. Enter LooseSettled when (support AND linear <= Enter AND angular <= Enter) held
  for EnterDwell (reset the dwell on any failing sample). Exit immediately on loss of support, or when linear > Exit
  or angular > Exit for ExitDwell. A missing body / missing velocity reads as unsettled with one `ck::Trace` warning
  per entity, never as zero velocity. The body needs `Set_PersistContacts(Enable)` - the subclass builds its own body
  (see D2).
- Transitions between placements apply the spec's rules: entering `Transfer` FREEZES the warning (WarningElapsed kept,
  phase Dormant, no voice); entering `Loose` or `Protected` CANCELS it (WarningElapsed = 0, phase Dormant) and keeps
  LastScreamCommittedAt and ScreamSequence; entering `Held` or `LooseSettled` resumes/starts the cycle.

Vocal cycle (only while Placement is `Held` or `LooseSettled`): if a cooldown is pending (`Clock <
LastScreamCommittedAt + Cooldown`) stay in `RecoveryIdle` (or `Recover` while its clip time runs) until it expires;
then `Anticipate` (0.3) -> `Inhale` (1.2) -> at the instant Inhale completes, COMMIT: `ScreamSequence += 1`,
`LastScreamCommittedAt = Clock`, `LastWorldPosition = WorldItem root world location` (if the transform is missing,
suppress the commit with a warning - no ZeroVector), broadcast `OnScreamCommitted(handle, sequence, position)`; then
`Scream` (0.6) -> `Recover` (1.0) -> `RecoveryIdle` until the cooldown expires -> `Anticipate`. Phases advance from
the accumulated kernel clock with carry-over (a phase that ends mid-tick starts the next with the remainder), but at
most ONE commit per pass: a long hitch emits one scream and schedules the next from its actual commit. Zero or
negative/non-finite delta advances nothing. Resuming from `Transfer` into an eligible placement continues the warning
from `WarningElapsed` (Anticipate/Inhale progress), not from zero. `Request_Suspend` behaves like entering `Loose`
(cancel, keep history) and blocks the cycle until the next tick re-derives placement.

Signals (delegate/event `_MC` pairs, bind/unbind mixins): `OnPlacementChanged(handle, prev, new)`,
`OnPhaseChanged(handle, prev, new)`, `OnScreamCommitted(handle, int32 sequence, FVector worldPosition)`.
Readers: `Get_Placement`, `Get_Phase`, `Get_ScreamSequence`, `Get_LastScreamCommittedAt`, `Get_WarningElapsed`,
`Get_HasSupport`, `Get_SecondsUntilNextWarning` (TOptional).

### D2 - item definition, world item subclass, presentation adapter (new files only)

- `Script/Items/Mars_Item_ScreamingTurnip.as`: `asset Mars_ItemDef_ScreamingTurnip of UCk_InventoryItem_Definition`,
  accessor `mars_items::ScreamingTurnip()`. Presentation: Visual.Mesh = the static PROXY (placeholder now, see
  Assets), `MeshScale` so the proxy is ~9 x 8 x 10 cm; Grip TwoHanded, Layout `Cradle` (gloves cup it from below),
  Shape as the Cookbook/Root do; Mounting Persistent, CarryPoint the existing hand/bag carry point other two-handed
  ingredients use, `HeldOffset` tuned so the proxy sits in the cupped gloves; WorldItem.ScriptClass =
  `UMars_ScreamingTurnip_EntityScript`; traits: `Throwable` (same numbers as `Add_BlockoutTraits`). Do NOT touch
  `Mars_ItemDef_Root`. Display name "Screaming Turnip".
- `Script/WorldObjects/Items/Mars_ScreamingTurnip_EntityScript.as`: `UMars_ScreamingTurnip_EntityScript :
  UMars_WorldItem_EntityScript`, `default Definition = mars_items::ScreamingTurnip()`. Follow the Cookbook: Super
  construct, ensure World + Persistent, hide the static proxy in `DoOnVisualMeshAdded`, add a scene node with the
  presentation component (`UMars_ScreamingTurnipPresentationComponent`, `TickViaProcessor`), compose the kernel
  `utils_screaming_turnip::Add(Root, Spec{Parts.WorldItem = this item})` once the world item exists, bind
  `OnPhaseChanged`/`OnPlacementChanged` to the presentation, unbind everything in `DoEndPlay` then Super. The body must
  have `Set_PersistContacts(Enable)`: if the base `AddBody` cannot be configured, build the body in the subclass the way
  `UMars_FoodItem_EntityScript` builds its own `FMars_WorldItem_Composition` and calls `Compose_WorldItem` (read it);
  prefer the smallest change that keeps the base pickup/holder path intact. No FoodPiece, no station traits.
- `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`: `USkeletalMeshComponent` subclass modelled
  on the Cookbook component: AnimationSingleNode, NoCollision, no shadow is fine, transform push enabled like the
  Cookbook, loads the SK and clips by soft path (Assets below), maps phase -> clip: Dormant -> `ROOT_QuietIdle` (loop),
  Anticipate -> `ROOT_Anticipate`, Inhale -> `ROOT_Inhale`, Scream -> `ROOT_Scream`, Recover -> `ROOT_Recover`,
  RecoveryIdle -> `ROOT_RecoveryIdle` (loop); placement `Loose` without support -> `ROOT_AirborneLeafTrail` (loop),
  `Loose` with support / `Transfer` -> `ROOT_QuietIdle`. `PlayAnimation(clip, loop)` only on a CHANGE (never per
  frame); when a clip asset is missing, log one warning and keep the skeletal mesh in its ref pose (or the placeholder
  static sphere if the SK is missing) - gameplay never depends on it. The component never writes gameplay state and
  never reads animation notifies to decide anything. The impact-squash/settle-rock overlays are optional: do them only
  if a contact-added binding with `Get_RelativeNormalSpeed` > 150 cm/s and a 0.3 s debounce is cheap; otherwise list
  them as not done.
- Audio/VFX: none required. If a cue hook is trivial, broadcast nothing new - the kernel's `OnScreamCommitted` /
  `OnPhaseChanged` are the hooks.

### D3 - planted source (new files only)

- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`: `UMars_ScreamingTurnipBed_EntityScript`
  (base: `UMars_ForageSource_EntityScript` if its hooks fit an unarmed pull with no Health/HitZone/knock body;
  otherwise `UCk_GenericEntityScript_UE` composing `utils_forage::Add` directly - say which and why). Composition:
  transform at `SpawnTransform`; a release node ~20 cm above the bed centre as `Parts.ReleasePoint`; Forage spec:
  Yield `mars_items::ScreamingTurnip()`, 1 charge, Exhaustion `Persists` (one-shot bed, no regrow), Launch a small hop
  out of the bed (about (+60, 0, +120) in the bed frame, tune so it lands on the floor next to the bed within reach);
  a Use interaction target (`InteractionChannel_Mars_Use`, `Mars_IA_Interact_Use`, prompt "Pull {name}") with
  CompletionPolicy Timed, duration Grip 0.2 + Tug 0.5 = 0.7 s, `RequiresFreeHands = true` (unarmed), ReachKind Hold,
  Work AfterCompletion; on `OnInteractionFinished(Succeeded)` -> `Forage.Request_Release(Plucked)`; on cancel/fail
  nothing is consumed. Disable the target while a release is pending and after exhaustion (`OnExhausted`). Visuals:
  a planted skeletal visual (same SK, `SRC_Idle` loop, sunk so the bulb's magenta shoulder is at the soil line) swapped
  for the empty-bed look on `OnReleased`; before Phase C exists, a static placeholder (sphere + bed slab) with the
  same show/hide logic. Grip/tug/release/cancel clips (`SRC_Grip`/`SRC_Tug`/`SRC_Release`/`SRC_Cancel`) are played
  by the source presentation from the interaction's start/cancel/finish signals if they are reachable; otherwise list
  as not done. The released world item is the normal Forage -> `Request_SpawnWorld` yield; the bed never spawns a
  second item, never parents the yield, and never destroys it.
- Sandbox / review placement: do NOT edit `Sandbox_Mars_MAP` or any live map. Add
  `Script/Editor/Mars_ScreamingTurnip_MapBuilder.as` with a human-run console command `Mars.ScreamingTurnip.BuildReviewRoom`
  (pattern: `Script/Editor/Mars_CellarBat_MapBuilder.as`) that places, in the CURRENTLY OPEN level, a floor slab, one
  bed, a PlayerStart and a second bed 10 m away; it never loads a level. Phase C/E will run it in the review map.

### D4 - tests `Script/Tests/ScreamingTurnip/` (new files), rig `Mars_AutoTestRig_ScreamingTurnip.as`

Use SHORT spec timings in tests (e.g. Anticipate 0.1, Inhale 0.2, Scream 0.1, Recover 0.1, Cooldown 0.6: period 0.9 s)
so three screams take ~3 s; assert the arithmetic (start-to-start == Cooldown + Anticipate + Inhale within one tick),
never the production numbers. Spawn the item with the def through `utils_world_item::Request_SpawnWorld` or the
entity script, on a `Spawn_StaticSlab` floor; carrier rig from `Mars_AutoTestRig_PickupByPress` where a hand is needed.
Required tests (names are `Mars_AutoTest_ScreamingTurnip_<Name>`):
1. `SettlesOnAFloorThenScreamsOnTheClock` - spawned loose above a slab: Placement goes Loose -> LooseSettled (dwell
   honoured), then 3 `OnScreamCommitted` with sequences 1,2,3 and start intervals == period; one broadcast per commit.
2. `HeldScreamsAndAThrowSilencesIt` - picked up / seeded into the held slot: Held placement, >= 1 scream; a throw
   during Inhale -> Placement Loose within a frame, phase Dormant, no commit during flight, sequence unchanged; after
   landing a FULL fresh warning runs before the next scream and the cooldown from the last commit is respected.
3. `TransferPreservesTheWarning` - from LooseSettled with WarningElapsed > 0, a pickup to Held: WarningElapsed is not
   reset across the Transfer, the next scream comes earlier than a fresh warning would allow.
4. `StowSilencesAndUnstowRestartsTheWarning` - item moved to a non-selected hotbar slot (Carried): Placement Protected,
   phase Dormant, no commits; back to the held slot: fresh warning, cooldown honoured.
5. `TwoRootsKeepIndependentClocks` - two items spawned 0.4 s apart on the slab: sequences and commit times are
   independent; no shared state.
6. `DestroyMidWarningEmitsNoFinalScream` - destroy the entity during Inhale: no commit, no callback after destruction
   (signal unbound), no ensure.
7. `AnUnarmedPullReleasesOneRootAndEmptiesTheBed` - bed + carrier: hold Use through 0.7 s -> exactly one yield world
   item, bed exhausted, target disabled, `OnReleased` reason Plucked; a second hold releases nothing.
8. `ACancelledPullKeepsTheCharge` - release the press at 0.3 s: no yield, charge 1, target still enabled.
Also keep the existing coverage green: `--test-pattern WorldItem`, `Forage`, `Cookbook`, `FPHands`, `HeldItem`.

### D5 - Assets (placeholders until Phase C)

Final paths (do not create them; Phase C will): SK `/Game/ArtCandidates/ScreamingTurnip/R01/Meshes/ScreamingTurnip_R01_Mars_SK`,
clips `/Game/ArtCandidates/ScreamingTurnip/R01/Animation/ScreamingTurnip_R01_<Clip>_Mars_ANIM` (Clip = `ROOT_QuietIdle`,
`ROOT_Anticipate`, `ROOT_Inhale`, `ROOT_Scream`, `ROOT_Recover`, `ROOT_RecoveryIdle`, `ROOT_AirborneLeafTrail`,
`ROOT_ImpactSquash`, `ROOT_SettleRock`, `ROOT_PlaceSettle`, `SRC_Idle`, `SRC_Grip`, `SRC_Tug`, `SRC_Release`, `SRC_Cancel`),
static proxy `/Game/ArtCandidates/ScreamingTurnip/R01/Meshes/ScreamingTurnip_R01_Collision_Mars_SM` (with sockets
`Grip_L`/`Grip_R`), bed `TurnipBed_R01_Mars_SM` / `TurnipBedEmpty_R01_Mars_SM`. Put every path in ONE constants
namespace (`constants_screaming_turnip_assets`) so the swap after Phase C is a one-file edit. Until they exist: the
item's Visual.Mesh is `engine::Sphere()` scaled to ~9 cm (sockets absent -> Cradle layout from bounds / `Grip.HalfWidth`),
the presentation component logs one warning and shows nothing extra, the bed uses engine primitives. Headless tests
must not depend on any ArtCandidates asset.

## Gates (toolbox, test-only path, editor open -> quiescence protocol: no `.as` edits while a run is in flight)

- Before the first `Script/` edit, capture: `./CkAuto/UnrealToolbox.exe --test --discover-fresh --test-pattern WorldItem
  --output=Saved/Logs/Test-Turnip-Baseline-WorldItem.log --project=D:/Repositories/CkRepos/Orion/Mars.uproject` and the
  same for `Forage` and `Cookbook` (three short runs; record pass/fail counts and failing names in PROGRESS.md).
- Iterate with `--test --discover-fresh --test-pattern ScreamingTurnip`; finish with one run each of the five patterns
  above plus `ScreamingTurnip`. No full gate, no `Mars` lane. Report which pattern produced which result, and name any
  NEW failure with its solo re-run verdict (`--parallel 1 --known-reds off --test-pattern "<full path>"`).
- Run long toolbox runs in the background with a 10-minute timeout and wait for the notification; do not poll.

## Hard rules

- New files only, under `Script/ECS/ScreamingTurnip/`, `Script/Items/Mars_Item_ScreamingTurnip.as`,
  `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`,
  `Script/WorldObjects/Items/Mars_ScreamingTurnip_EntityScript.as`,
  `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`, `Script/Editor/Mars_ScreamingTurnip_MapBuilder.as`,
  `Script/Tests/ScreamingTurnip/`, plus ONE entry in `Script/Generated/DynamicHandleTypes.json` and tag lines in
  `Config/DefaultGameplayTags.ini` only if a new tag is unavoidable (ids are tags: e.g. `Item.Mars.ScreamingTurnip` if
  the item path needs one; prefer none). Everything else in the tree is another session's and stays untouched -
  including the 70+ already-dirty paths. No git operations. No submodule edits. No live map edits. No RootMaw edits.
- Mars conventions: `Mars_` prefix, typed handle + `utils_screaming_turnip`, request doctrine (processors are the only
  fragment writers), `Validate()` mixins, <= 3 params per function (structs beyond), TOptional over sentinels, ids as
  tags, brace layout (`{ return X; }` single-return bodies; blank line after every closing brace), `.As_X()` casts.
  Fragments hold no strong UObject refs (soft pointers / handles only).
- Authority decides phase; presentation follows. Missing renderer/audio changes nothing. No animation notify drives
  gameplay. No per-frame `PlayAnimation`.
- Do not hide a failure with a sleep, retry or guard; find the responsible boundary. If a real API blocker appears
  (e.g. the body cannot be given PersistContacts without rewriting the base), stop, record exact evidence in
  PROGRESS.md, do every other deliverable, and report the boundary.
- Fill the Phase D section of `PROGRESS.md` (files, design facts confirmed by reading code, gate runs with counts and
  names, deviations, not verified), each claim marked **confirmed**/**inferred**.

## Reporting back (your final message)

Files (paths, one line each); the design facts you confirmed (where the body is built, how support/angular speed are
sampled, which interaction route the bed uses, how the presentation follows the held node); baseline vs final gate
results per pattern (counts + failing names + solo verdicts); the eight tests' status; what is placeholder pending
Phase C (exact lines to swap); what remains unverified (PIE, visuals). Confirmed vs inferred on every claim.
