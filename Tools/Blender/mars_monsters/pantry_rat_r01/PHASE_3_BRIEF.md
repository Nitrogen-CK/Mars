# Phase 3 brief - Pantry Rat: PantryRaid / RatDen / PantryRat kernels, guarded original-item theft, routed tests

You are the executor for Phase 3 of `docs/art/pantry-rat-dens-production-r01/`. Phases 1 and 2 are done (see this
folder's `PROGRESS.md` and the package `PROGRESS.md` for what exists: candidate assets under `/Game/ArtCandidates/PantryRat/R01/`,
sockets `Carry_Mouth`/`Carry_Drag` on `jaw`, two rat-local Masked looks, `Mars_PantryRat_Look_Assets.as`). Read, in order:
1. `docs/art/pantry-rat-dens-production-r01/PHASE_3.md` (the gate), `DESIGN_TECH_SPEC.md` sections 6-9 and 13 (state table,
   eligibility, guard, routing, transaction, scheduler), `ACCEPTANCE.md` rows R01-R14, R17-R19, R23, R25-R28, `VALIDATION.md`.
2. The three digests in the package folder - they are the real APIs with file:line, read them completely and re-open each cited
   file before using it: `DIGEST_INVENTORY_THEFT.md`, `DIGEST_NAV_HEALTH_COMPOSITION.md`, `DIGEST_EYES_DITHER.md`.
3. Project doctrine: `CLAUDE.md` (Mars gameplay script conventions: typed handles, request doctrine, utils_ namespaces, <= 3
   params, Add(Handle, Spec), Validate mixin, no strong UObject refs in fragments, stations' three layers),
   `Plugins/CkFoundation/Script/ARCHITECTURE.md` sections 8 and 21, and the skills
   `C:/Users/Adam/.codex/skills/ck-game-feature-recipe/SKILL.md`, `ck-game-driver-architecture/SKILL.md`,
   `ck-game-testing-discipline/SKILL.md` (discovery timing, deferred requests, same-commit tests, contamination traps).
4. Neighbouring code to mimic, in full: `Script/ECS/ScreamingTurnip/` (newest feature shape), `Script/ECS/Bat/` +
   `Script/WorldObjects/Monsters/Mars_CellarBat_EntityScript.as` (creature composition, HFSM, Monster/Health/HitZone, skeletal
   mesh + AS AnimInstance), `Script/ECS/CargoSlot/`, `Script/ECS/WorldItem/`, `Script/WorldObjects/Items/Mars_WorldItem_EntityScript.as`,
   `Script/ECS/SurfaceNavigator/`, `Script/Tests/SurfaceNavigator/Mars_AutoTestRig_GroundNavBuildOutcome.as`,
   `Script/Tests/Backpack/Mars_AutoTest_CargoSlot_ATransferThatFailsBroadcasts.as`, `Script/WorldObjects/Eyes/Mars_EyesDummy_EntityScript.as`.
5. `CkAuto/.claude/skills/build-test/SKILL.md` before any Toolbox run.

## Environment and ownership
- Editor open (Monolith only; never close/restart/minimise; never console level loads; never delete/reload loaded assets).
  AngelScript hot-reloads in the live editor on save: read the live log tail for `Angelscript: Error` after each batch of
  edits and fix before moving on. Freeze `.as` edits during every Toolbox run.
- Branch dev; unrelated dirt in the tree (Crawler, Cookbook, Sandbox, Jolt, Script/Generated) stays untouched. No git writes.
- New owned files: `Script/ECS/PantryRaid/Mars_PantryRaid_{Feature,Utils,Processor_Requests,Processor_Tick}.as`,
  `Script/WorldObjects/Monsters/Mars_PantryRaid_EntityScript.as`; `Script/ECS/RatDen/Mars_RatDen_{Feature,Utils,Processor_Requests}.as`,
  `Script/WorldObjects/Monsters/Mars_RatDen_EntityScript.as`; `Script/ECS/PantryRat/Mars_PantryRat_{Feature,Utils,Processor_Requests,
  Processor_Tick,Processor_Setup,Hfsm,AnimInstance}.as`, `Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as`;
  `Script/Items/Traits/Mars_ItemTrait_StinkyCheese.as`, `Mars_ItemTrait_PantryIngredient.as`, `Script/Items/Mars_Item_PantryIngredients.as`;
  `Script/Tests/PantryRat/*.as`, `Script/Tests/RatDen/*.as`, `Script/Tests/PantryRaid/*.as`; `Saved/Logs/PantryRatValidation/**`.
- Existing files you may change, each named in PROGRESS before the edit, additive only: `Script/Generated/DynamicHandleTypes.json`
  (hand-add the three handle entries - headless boots cannot self-heal it), `Config/DefaultGameplayTags.ini` (new tags:
  `AttachPoint.Mars.RatMouth`, `Inventory.Mars.RatPocket`, `Monster.Mars.PantryRat`, `HitZone.Mars.Body` if absent,
  `Probe.Mars.*` only if needed), `Script/Items/Mars_Item_Ingredients.as` (add the PantryIngredient marker trait to the
  forage defs - nothing else), `Script/ECS/SurfaceNavigator/Mars_SurfaceNavigator_{Feature,Utils,Processor_Requests}.as`
  (ONE additive request `FMars_Request_SurfaceNavigator_SetSpeed { float32 Speed; }` drained before MoveTo that overrides
  the spec speed used by Tick; existing behaviour unchanged, existing tests must stay green).
  Never: CargoSlot, WorldItem, Eyes, Health, HitZone, Monster, Backpack, any plugin, production maps.

## Phase 2 outcomes that bind this phase (measured in the live editor, 2026-11-07)

- **CPD 14 unwritten = the rat is invisible.** A primitive whose custom primitive data stops at index 13 renders nothing
  (`review/phase2/unreal/close_Rat_Cpd14Unset.png`); the material default of 1.0 is NOT applied. Seed CPD 14 = 1.0 on the
  skeletal mesh component before its first visible frame, and seed it again on any primitive you swap in. The Eyes feature
  writes 0..13; use `utils_pantry_rat_look::Get_FadeAlphaCpdIndex()` for 14, never a literal.
- **Dither = white-noise hash per UV cell**, not the verbatim BusterBlock IGN line (that aliased into stripes; planner ruling,
  rat-local .ush only). Same contract: Masked, FadeAlpha 1 = solid, 0 = gone. Phase 3 writes FadeAlpha only as the constant
  1.0; ramps are Phase 4.
- **Assets (saved, cold-read proven by `Mars_AutoTest_PantryRat_CandidateAssetsReload`)**: `/Game/ArtCandidates/PantryRat/R01/`
  `Meshes/PantryRat_R01_Mars_SK` (+ `_SKEL`), `Animation/PantryRat_R01_<Clip>_Mars_ANIM` x34 (frame counts and loop flags in
  `review/phase2/clip_table.md`; EarFlick/TailSettle are additive on IdleBreath frame 0), `Props/PantryRat_R01_{Den,DenEyePlate,
  Cheese}_Mars_SM`, `Materials/PantryRat_R01_<Slot>_Mars_MI` for Body/Pink/Belly/Wood/Harness; slot 5 `EyePatch` carries the raw
  `MarsPantryRatEyePlate` master. Sockets on `jaw`: `Carry_Mouth` (item pivot = base centre, cap forward-down) and `Carry_Drag`
  (bulky, pivot on the floor ahead); both proven at rest to 0.0 cm. The clip is the bound's gait: BoundCycle is a 0.4 s loop whose
  stance feet move 36-59 cm/s in the clip, so pick the unloaded/loaded navigator speeds in that band and name the slip you accept.
- **Pocket geometry (real SM_PlayerBackpack x1.25)**: the cargo sockets sit 0.7-2 cm proud of the render surface, but the mesh's
  simple collision stands 10.4 cm proud of the pocket face. The rat acts at the SLOT SOCKET (raise the snout to the socket height,
  nose at the collision surface); never raycast "for the item". Only Pocket2/Pocket3 (37.5 cm up) are claimable; Pocket1 at 75 cm
  is out of reach (planner decision, Phase 1).
- **Do not Save All, do not save the GeneratedLooks folder or `M_CkUsf_Look_MarsEyePlate`.** Phase 2's recompile calls left the
  shared `M_CkUsf_Look_MarsEyePlate` and both rat masters dirty in memory only. Save only the assets you created, by name,
  with `save_loaded_asset`.
- **Hot-reload trap (cost Phase 2 one reload)**: the CkAutoTest populator generates the wrapper actor classes in
  `Script/Generated/Mars_AutoTestActors.as`; never hand-write a class with a name the generator emits. `Get_ExpectedLogErrors`
  is an override on the `UMars_AutoTest_X : UCk_AutoTest_Base` class itself (pattern:
  `Script/Tests/AttachPoints/Mars_AutoTest_AttachPoints_LookupByTag.as:90`). Freeze every `.as` and `.ush` edit while a Toolbox
  run is in flight; one run per edit batch.
- **Review map** `/Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Review_MAP` exists (static rats in bind pose, a playback
  row, a den with lit eyes, a real mushroom). Use it for look checks; build your court test rig in the AutoTests map as the
  brief says, never in that review map or any production map.
- The Eyes known reds (`Mars_AutoTest_EyesDummy_ComposesAndWrites`, `Mars_AutoTest_Eyes_LookMasterResolves`) are unchanged
  and expected to stay red under the headless gate; report them by name as "Still red (listed)", never as yours.

## Architecture (planner rulings - implement these, in house style)

### Items
- `UMars_ItemTrait_StinkyCheese` and `UMars_ItemTrait_PantryIngredient`: marker traits with `Has_StinkyCheese` / `Has_PantryIngredient`
  mixins (pattern `Mars_ItemTrait_HandsOnly.as`). `Mars_ItemDef_MonksRind` (Script/Items/Mars_Item_PantryIngredients.as): Transient,
  blockout-style presentation using the candidate cheese mesh `/Game/ArtCandidates/PantryRat/R01/Props/PantryRat_R01_Cheese_Mars_SM`
  (TSoftObjectPtr), + StinkyCheese trait, no Food/cooking traits. `mars_items::MonksRind()` accessor.
- Eligible-to-steal predicate (utils_pantry_raid): `Item.Has_Food() || Item.Has_PantryIngredient() || Item.Has_StinkyCheese()`,
  never Backpack/HandsOnly/Strike items.

### PantryRaid (encounter driver, Script/ECS/PantryRaid + EntityScript)
- `utils_pantry_raid::Add(FCk_Handle& InOwner, FMars_PantryRaid_Spec)`; Spec: `FBox EncounterBounds` (local to the owner),
  population {ResidentsPerDen 2, MaxActiveRats 6, EmergeSpacingSeconds 4, DeadReplacementSeconds 30}, scent {GroundArmSeconds 3,
  ScentRangeCm 1200, NoTargetReturnSeconds 2}, guard {GuardEnterCm 220, GuardExitCm 320, AvoidEnterCm 300, AvoidExitCm 380,
  ClearDwellSeconds 1, SameFloorCm 150}, routing {LoadedPortalKeepOutCm 150, DecisionIntervalSeconds 0.2}, theft
  {InspectSeconds 0.4, RummageSeconds 1.6, LeaseSeconds 3}, speeds {Creep 100, Approach 240, LoadedFlee 320}, hop
  {MaxLiftCm 8}, `TSoftObjectPtr<UCk_InventoryItem_Definition>` is NOT in the spec (presentation data lives in the entity script).
  Group sub-structs; each has a Validate mixin; the Spec's Validate chains them.
- State: registry of dens (handles), live rats (handles + resident slot id), pack records {Pack handle, ScentArmedAt, Eligible slots,
  Lease {Rat, Slot, ExpectedItem, SourceInventory, Token, Expiry}}, latest chef snapshots {Root handle, Location, floor z},
  NextOperationId, Epoch. One lease per pack.
- Readiness (driver skill rules; stamp a Ready tag LAST): the GroundNavVolume the raid is given (Spec field `FCk_Handle` NavVolume
  OR discovered by tag inside the bounds) reports `Get_IsBuilt() && Get_IsBuildCurrent()` AND `utils_nav_surface::Try_FindPathSync`
  between the den's OutsideStand and a point inside the bounds returns `Success`; dens discovered (persistent tag query,
  delta-gated, scoped to the bounds); at least one den. No sleeps.
- Tick (Processor_Tick, FGroup_Gameplay_Script): refresh chef snapshots from `utils_entity_tag::ForEach_Entity(Self, n"TAG_MarsCombatTarget")`
  filtered to `As_Hotbar(UnChecked)`-valid roots (chefs, not monsters), planar positions; refresh pack records from backpacks
  inside the bounds (`Pack.Get_Mount() == World`, `Get_IsSettled()`, contains a StinkyCheese item, at least one eligible item in a
  slot whose mount point is <= 48 cm above the floor - Phase 1 reach - and not leased); arm scent after GroundArmSeconds;
  expire leases; decide emergences (spacing, cap, resident budget) and issue `Request_Emerge` to a den; everything else is a
  request drained by Processor_Requests. Guard test for a pack: any chef within GuardEnterCm planar and |dz| < SameFloorCm
  (hysteresis per pack: Guarded until all chefs beyond GuardExitCm for ClearDwellSeconds). Threat test for a rat: nearest chef
  within AvoidEnterCm / clears beyond AvoidExitCm. Optional static LOS via a Jolt static ray as `utils_bat::Get_IsStaticBetween`
  does (game world only); record whether you used it.
- Lifetime: rats are spawned by the raid (`utils_entity_script::Request_SpawnEntity(RaidEntity, UMars_PantryRat_EntityScript, Params)`),
  owned by the raid, NEVER by a den; den removal cannot destroy a rat. `DoesNotReplicate` everywhere in this slice (the
  inventory/WorldItem path is local-only; multiplayer is a recorded release blocker, not your problem).

### RatDen (Script/ECS/RatDen + EntityScript)
- `utils_rat_den::Add(FCk_Handle& InOwner, FMars_RatDen_Spec)`; Spec: portal frames in den-local space from Phase 1
  (`EntryPortal (24,-14,0)`, `ExitPortal (24,14,0)`, `OutsideStand (75,0,0)`, `ReturnAdmission (48,0,0)` in Blender cm -> UE
  (x, -y, z)), `ResidentCount`, `EyePlate` (FCk_Handle_UnrealComponent, optional - tests pass none). State: resident slots
  {Dormant, Pending, Outside, DeadCooldown{until}}, PendingOperationId, EyeOccupancy. Requests: Emerge{OperationId}, AdmitReturn{Rat},
  ResidentDied{Slot}, SetEyes{occupied}. Signals: OnEmergeReady(Den, Slot, OperationId), OnResidentReturned. The den NEVER
  admits a rat whose pocket is non-empty (`Request_TryRemove` of the request + a logged, non-ensuring refusal result in the
  signal/request result). The entity script owns the den mesh, the recess, the eye plate component with the SHARED
  `utils_eyes::Look_EyePlate()` master and `utils_eyes::Add(FaceNode, Spec)` + `Request_SetPlate` (EyesDummy pattern), style
  Wide, blink + look; eyes shown only while a resident is Dormant (SetEyes), black (Strength 0 / style blank cell 0) when vacant.
  During a resident's Emerge/Return the proxy pair for THAT slot is off (no duplicate eyes).

### PantryRat (Script/ECS/PantryRat + EntityScript + Hfsm + AnimInstance)
- `utils_pantry_rat::Add(FCk_Handle_Transform& InRoot, FMars_PantryRat_Spec)`; Spec: {Raid handle, Den handle, ResidentSlot,
  OperationId, speeds/hop from the raid's spec (copied values, not a handle chase), HurtboxHalfExtents (20, 15, 17)}.
  Composition order (Bat pattern): `utils_surface_motion::Add(InRoot, MotionSpec)` (Rays, Slide, Clearance ~18, MaxStepHeight 12,
  MaxSpeed 340) -> `utils_surface_navigator::Add(Motion, FMars_SurfaceNavigator_Spec(100, 30, 2, 15, 25))` ->
  `utils_monster::Add(Root, FMars_Monster_Spec(Monster.Mars.PantryRat, FMars_Health_Spec(1, 1, Enable /*invulnerable*/),
  Make_FleshZoneSpec(HitZone.Mars.Body, 1), CorpseSeconds unused, Team Two))` -> `utils_hit_zone::AddHurtbox_Box(Zone, Root, Hurtbox)`
  -> attach points (`utils_attach_points::Add` publishing `AttachPoint.Mars.RatMouth` on a scene node at the jaw socket's rest
  frame; the entity script re-parents that node to the skeletal `Carry_Mouth` socket when the mesh exists) -> pocket inventory
  `utils_inventory_data_only::Make_Params_Bounded(Inventory.Mars.RatPocket, 1, FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(
  UMars_PantryRat_PocketPolicy CDO, n"OnCanAccept"), ...)`, NoStacking, PersistContents Disable, `Add(PocketEntity, Params, DoesNotReplicate)`
  on a child entity whose lifetime owner is the rat (so `Get_LifetimeOwner(Inventory)` resolves the rat in the policy), then
  `utils_world_item::Add_MountedInventory(Pocket, FMars_Fragment_MountedInventory(PointAtOffset, AttachPoint.Mars.RatMouth, CarryOffset))`
  -> fragments (Params, State, Requests, Signals, NeedsSetup) -> `utils_state_machine::Add(Root, FCk_StateMachine_Spec(UMars_SmState_PantryRat_Alive))` LAST.
- State fragment: Phase (enum exactly the spec's table), PhaseStartedAt, Target {Pack, Slot, ExpectedItem, Token}, Threat snapshot,
  Route {Goal, Epoch, PathMode}, BurstCount, PauseDeadline, Loot (FCk_Handle_Item, exact), CarryReceipt, LethalPending,
  DeathSequence, ReleaseOperationId, ReleaseReceipt, CorpseDeadline, FadeAlpha (presentation reads it). Single-writer:
  `UMars_Processor_PantryRat_HandleRequests` drains in the spec's priority (destruction guard, lethal, inventory results, context
  changes/claim cancellation, nav results, deadlines/Advance). HFSM tasks only enqueue requests and read state; the raid only
  enqueues requests on rats.
- **Theft transaction** (the framework fact that makes it safe: the TARGET inventory's custom accept delegate runs at drain time
  inside the CkInventory operation coordinator and a refusal rolls the item back - DIGEST_INVENTORY_THEFT.md section 3):
  1. Inspect/ClaimTell: the raid grants a lease {Rat, Pack, Slot, ExpectedItem, Token, Expiry}; the rat plays InspectSlot + Rummage
     for InspectSeconds + RummageSeconds while re-checking guard every tick (abort -> cancel lease, Observe).
  2. ClaimTransfer: the rat enqueues `FMars_Request_PantryRat_Claim` -> the drain issues
     `SlotInventory.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(ExpectedItem, Pocket),
     FCk_Delegate_Inventory_OnOperationResult_Transfer(PolicyOrProcessorCDO, n"OnClaimTransfer"))` - NEVER FMars_Request_CargoSlot_Take.
  3. `UMars_PantryRat_PocketPolicy::OnCanAccept(Inventory, Item, bool& Out)` (the drain-time predicate): resolve the rat from
     `utils_entity_lifetime::Get_LifetimeOwner(Inventory)`; Out = rat alive && !LethalPending && Phase == ClaimTransfer && pocket empty
     && Item == Target.ExpectedItem && Item.Get_ParentInventory() == the leased slot inventory && the pack is still grounded/settled
     && the raid's lease token matches && NO chef guards the pack right now (read chef roots' CURRENT transforms, not a cached
     snapshot) . Any false -> refused -> CkInventory rolls back and logs its Warning
     `TransferItem: Target [...] refused add of [...]`; the rat's callback maps Failed_RejectedByCustomAcceptanceLogic /
     Failed_SourceNotInInventory / Failed_OperationCancelled to a benign Contended/Cancelled result, cancels the lease, returns
     to Observe. No ensure on the rat path. Tests that exercise contention list that exact Warning in `Get_ExpectedLogErrors`.
  4. Accepted: the callback's `InNewItemInTarget` must equal the original handle (entity-preserving transfer) and
     `Item.Get_ParentInventory() == Pocket`; then CarryMountPending: Persistent food mounts its own WorldItem body on
     `AttachPoint.Mars.RatMouth` through the existing Reconcile path - the receipt is the food's `OnMountSettled(Carried)`;
     a transient item gets ONE Visual world item via `utils_world_item::Request_SpawnVisual(Rat, FMars_WorldItem_VisualSpec(Item,
     MouthNode transform, Offset))` (CargoSlot Sync pattern) - the receipt is its construction promise. Only then FleeWithLoot.
  5. Bulky items (Carry_Drag): if the item's presentation half-width > 10 cm use the Carry_Drag offset; never exclude a type.
- **Death prep (Phase 3 scope: the receipts, not the dither)**: on `Request_TakeHit(ScaledEvent)` (bound from the Monster BodyZone
  OnHit in Processor_Setup) accept only `Event.Amount > 0 && Event.Source.Causer` is an item with `Has_Strike()` (use the generated
  `.As_Item()` / `.Is_Item()` handle mixins, never utils_x::DoCast) AND `Event.Source.Instigator` is a chef root (As_Hotbar valid).
  Accepted -> `Health.Request_SetInvulnerable(Disable)` + `Health.Request_ApplyDamage(Max)` in the same drain (the rat's Health is
  born invulnerable so cosmetic/monster contacts never deplete it; the Health drain applies SetInvulnerable before ApplyDamage and
  the once-only latch yields exactly one depletion even with the HitZone's own forwarded damage) + LethalPending + cancel lease.
  Monster OnDied -> Phase Dying -> if Loot valid: LootReleasePending; Persistent: `FoodWorldItem.Request_Release(FMars_Request_WorldItem_Release(
  Forward*80, Zero))` once per ReleaseOperationId, receipt = that world item's OnMountChanged(-> World) / refusal = OnReleaseRefused
  -> BlockedCleanup (visible, logged, never destroys the owner). Transient: spawn `UMars_WorldItem_EntityScript` with
  `Params().SourceItem = Loot; SourceInventory = Pocket; Mode = World; SpawnTransform = mouth + 12 cm forward`, receipt = constructed
  AND `Loot.Get_ParentInventory()` is the new holder. Then DeadHold (Phase 4 adds the fade/destroy). Never `utils_monster::Add_DespawnTimer`.
- Movement/routing: all goals through `Request_MoveTo` on the navigator; before admitting a raid/flee goal the rat (or raid) runs
  `utils_nav_surface::Try_FindPathSync` itself and requires `Success`; a navigator that reports `PathMode == StraightLine` for a
  raid/flee goal is a FAIL path (stop, rescore). Speeds via the additive `Request_SetSpeed`. Burst/observe rhythm: 1-3 bounds then
  Observe 0.6-1.5 s; loaded 2-3 bounds then FleePause 0.35-0.65 s. Candidate flee points: a ring of N (12) points inside the
  bounds scored per spec section 8, deterministic tie-break by index, loaded points >= LoadedPortalKeepOutCm from every den portal.
- Presentation (entity script, Bat pattern): skeletal mesh `/Game/ArtCandidates/PantryRat/R01/Meshes/PantryRat_R01_Mars_SK`
  (TSoftObjectPtr), per-slot MIDs from Phase 2, `UMars_PantryRat_AnimInstance : UAnimInstance` with BlueprintReadOnly phase/speed/
  carry/dead fields; in THIS phase drive clips with `USkeletalMeshComponent::PlayAnimation(Sequence, bLoop)` chosen per phase from
  a clip table in the entity script (no AnimBP yet - a named deviation; Phase 4 may build the blend graph). Eyes on the head:
  `utils_eyes::Add(FaceNode, Spec)` + `Request_SetPlatePrimitive(Mesh, EyePatchSlot)` with the rat-local
  `utils_pantry_rat_look::Look_EyePlate()` master on that slot (as the chef does with the shared one); `FApp::CanEverRender()`
  early-outs like the Bat. Seed CPD14 = 1.0 on the mesh BEFORE it becomes visible. Dead state = clear Emote, then
  `Request_SetStateExpression` with `utils_eyes::Expression_Downed()` (cell 20, no duration, no blink/look). Headless tests
  compose the feature with zero assets.

### Tests (Script/Tests/PantryRat, RatDen, PantryRaid) - one scenario per file, names say what is verified
Rig `UMars_AutoTestRig_PantryRaid : UMars_AutoTestRig_GroundNavBuildOutcome`-style: floor + built volume (wait on
`Get_IsBuilt`) + raid entity (bounds around the floor) + one den + a World-mode `UMars_Backpack_EntityScript` with a MonksRind and a
Mushroom (Persistent Food) stowed into slots 1 and 2 (the <= 48 cm pockets) + chef stand-ins = Carrier-rig entities tagged
`TAG_MarsCombatTarget` with a Hotbar, moved by setting their transform. Each test its own `_Origin` band. Required (map to the
rubric rows and say which in the file header):
R01 ReadinessGatesEmergence (no built volume -> no rat; built -> one pending emergence per slot, no duplicates), R02 DenEyesHandoff
(eyes on while dormant, off during Emerge, no two proxies for one slot), R03 UnattendedPackStaysTarget (chef leaves beyond 320 ->
lease granted), R04 NoTargetReturnsEmptyRats (cheese removed -> ReturnEmpty -> DenEnter admitted, resident Dormant), R05 SeatedChefGuards30s
(chef at 150 cm for 30 s -> no transfer ever issued; use the fixture clock), R06 ClosestValidThreatWins, R07 GuardHysteresisNoJitter
(oscillate 300/340 -> no claim, no phase flip-flop beyond one), R08 GuardArrivesBeforeCommit (chef steps to 100 cm after the Claim
request is enqueued but before the drain -> refused, item still in slot, rat Observe, expected Warning listed, no ensure),
R09 TwoRatsOnePack (one lease, one item moved, loser never duplicates), R10 PlayerTakeRace (CargoSlot Take by the carrier and the
rat claim in the same pass -> one winner, item count unchanged; the chef within interaction range is a guard so the rat loses),
R11 AnyIngredientEligible (forage with PantryIngredient, Persistent Food, cheese itself, bulky), R12 CheeseStolenStopsRecruitment
(loaded thief keeps fleeing), R13 LoadedRatNeverReturns (no chefs, no packs, 20 s -> still FleeWithLoot/FleePause, never
ReturnEmpty/DenEnter), R14 FleeRejectsDenMouth (every flee goal >= 150 cm from portals, PathMode Provider), R17 HitDuringTransfer
(lethal before commit -> no transfer; lethal after commit -> one release), R18 PersistentFoodReleasedOnce (same item handle, body
World, OnMountChanged receipt), R19 TransientForageAdopted (same item handle in the new holder, no clone), R23 LoadedFadeVeto
(a return/fade request on a loaded rat is rejected), R25 ReleaseRefusalBlocksCleanup, R26 DenRemovalKeepsLootCarrier,
R27 StaleCallbacksIgnored (old operation id -> no duplicate), R28 BoundRhythm (1-3 bursts then pause; root only moved by SurfaceMotion).
Plus compose tests for each Add. Regression lanes to re-run: `CargoSlot` (the failing-take test must still pass), `SurfaceNavigator`,
`Backpack`, `WorldItem`, `Eyes`, `Monster`.

## Process
1. Write items + feature files + handle JSON entries first; boot-check the live log for the self-heal transient ("'FCk_Handle_X' is
   not a data type" once, then clean); then utils + compose tests; then processors/HFSM + routed tests; then the entity scripts.
2. Toolbox runs detached per VALIDATION.md after each batch, patterns `PantryRat`, `RatDen`, `PantryRaid`, then the regression lanes
   above; each run its own dir; read `[population]`, `=== Known reds ===`, `Contaminated`, exit code from the real log. A run beside a
   live editor that reports `Full Reload is required` is contaminated, not failed: re-run after the editor settles.
3. If the drain-time predicate cannot see what it must (e.g. the policy cannot reach the rat or current chef transforms), STOP that
   gate with the exact framework code/log evidence in PROGRESS; do not retry-poll, do not edit a plugin.

## Reporting back
Files created/changed (existing edits named); the three handle entries; test list with the rubric row each proves; Toolbox run
dirs, exit codes, named results (new failures separately); regression lanes by name; the deviations (SetSpeed on SurfaceNavigator,
PlayAnimation instead of an AnimBP, Health born invulnerable); what remains unverified (visuals are Phase 4); the one claim you
would most expect to be wrong.
