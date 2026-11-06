# Phase 6a brief - Cellar Bat runtime candidate (kernel, HFSM, assembly, review map builder, tests)

You are the runtime executor for the Cellar Bat (prompt `docs/art/flying-units-r01/MODEL_ANIMATE_IMPORT_PROMPT.md`,
Phase 6; read it, `PRODUCTION_SPEC.md` sections 4-6, `ANIMATION_LIST.csv`, and `PROGRESS.md` beside this file). The
mesh/AnimBP come from a parallel Blender track; you build everything that does not need them, with a `WithVisuals`
switch so the candidate runs headless in tests and with a placeholder mesh in PIE until the real assets land.

Read first (these are the rulings you must follow): root `CLAUDE.md` (Mars gameplay script conventions: naming,
request doctrine, three layers, parameters, `Validate()` mixin, typed handle JSON), then the code named below. The Grep
tool skips `Script/*.as`; use `rg --no-ignore` via Bash or Read.

## Architecture decision (made; do not re-litigate)

Movement = **CkCrowd flying agent + CkVoxelNav path**, the stack CkFoundation already ships for flyers. Working
example to copy from: `Plugins/CkTests/Script/CkVoxelNav/CkVoxelNavGym_FlyingVsGrounded_PlayerController.as`
(volume entity creation, `FCk_VoxelNavVolume_Spec`, `Request_Build` with completion delegate, agent = child entity with
`utils_transform::Add` + `utils_crowd_agent::Add(transformHandle, FCk_CrowdAgent_Spec(radius, height).Set_AgentMode(
ECk_CrowdAgent_Mode::Flying))` + `utils_velocity::Add` + `utils_acceleration::Add` + `utils_euler_integrator::Request_Start`
+ `utils_voxel_nav_path::Add(agent, FCk_VoxelNavPath_Spec(radius))` + `utils_voxel_nav_path::Request_SetVolume`, then
`utils_crowd_agent::Request_MoveTo(FCk_Request_CrowdAgent_MoveTo(goal))`, signals `OnGoalReached` / `OnGoalFailed` /
`OnGoalBlocked`, `Request_Stop`, `Request_SetMaxSpeed`, `Get_MovementState`, `Get_TargetPitchDegrees`). Module docs:
`Plugins/CkFoundation/Source/CkVoxelNav/CLAUDE.md`, `Plugins/CkFoundation/Source/CkCrowd/Claude.md` (Flying tag section),
generated bindings `Plugins/CkFoundation/Script/Generated/utils_voxel_nav_*.as`, `utils_crowd_agent.as`.
The crowd agent is the ONLY writer of the bat root transform while alive; the bat kernel never writes the Transform
itself except in the DeathFall phase after the agent is disabled (`Request_EnableDisable(Disable)` - a disabled agent
may be relocated by its owner, per CkCrowd/Claude.md).

A blocked route therefore has an explicit outcome: `OnGoalBlocked`/`OnGoalFailed` from the agent, or
`OnPathFailed(outcome)` from the path. A lost target, a missing/unbaked volume (`NoBake`) and an invalidated perch are
explicit kernel outcomes too (signals + phase), never silent.

Attack = the project's real damage path, RootMaw's pattern (`Script/ECS/RootMaw/Mars_RootMaw_Processor_Tick.as`
lines ~226-257): during the committed Swoop phase the kernel sweeps a sphere each frame from the bat's mouth point
with `utils_damage_dealer::Request_StrikeSweep(FMars_DamageDealer_Sweep{Start, End, Radius, IgnoredEntities},
utils_damage_dealer::Make_Event(Dealer, Damage, DamageType))`, and a per-swoop ledger (`Committed`, `Generation`,
`HitZones`) guarantees exactly one damage result per committed swoop and none after cancel/death. Targets are entities
tagged `TAG_MarsCombatTarget` with hostile attitude (`utils_relationship::Get_AttitudeTowards(...) ==
ECk_RelationshipAttitude::Hostile`) - see `Script/ECS/Crawler/Mars_Crawler_Processor_Targeting.as` and
`utils_crawler::Get_IsCombatTargetValid` for the validity rules; copy the idea, not the crawler internals.

Monster plumbing = `utils_monster::Add(root, FMars_Monster_Spec(tag, health, zone, corpseSeconds, team))`
(`Script/ECS/Monster/`): Health + HitZone + team + `TAG_MarsMonster` + Dead byte attribute; death is latched by
`UMars_Processor_Monster_HandleRequests`, `BindTo_OnDied`. Death teardown pattern: `UMars_SmTask_Crawler_Die` in
`Script/ECS/Crawler/Mars_Crawler_Hfsm.as` (stop movement, disable zone, despawn timer via
`utils_monster::Add_DespawnTimer` + `Request_DestroyTimerOwner`).

## Files to create (new files only; additive registration)

1. `Script/ECS/Bat/` (kernel; headless, deterministic, no visuals, no input, no hint/label strings):
   - `Mars_Bat_Feature.as`: `asset Mars_BatHandle of UCkDynamic_HandleDefinition` (`FCk_Handle_Bat`,
     `FMars_Feature_Bat`), enums `EMars_Bat_Phase {Roosting, Alert, Launching, Patrolling, Approaching, Telegraphing,
     Swooping, Recovering, Returning, Braking, Perching, Hit, Stunned, Falling, Landed, Dead}`,
     `EMars_Bat_RouteOutcome`, `EMars_Bat_SwoopCancel {Cancelled, Interrupted, Died, TargetLost}`;
     `FMars_Bat_Spec` grouped into sub-structs (<= ~7 fields each): `FMars_Bat_Flight {CruiseSpeed, SwoopSpeed,
     MaxAcceleration, MaxTurnRate, AgentRadius, ArrivalRadius}`, `FMars_Bat_Sensing {AcquireRadius, LoseRadius,
     HomeRadius, SenseInterval}`, `FMars_Bat_Swoop {TelegraphSeconds, SwoopSeconds, RecoverSeconds, CooldownSeconds,
     Damage, DamageType, ContactRadius}`, `FMars_Bat_Roost {PerchLocation (world), PerchOwner (FCk_Handle, optional),
     HangOffset, AlertSeconds, LaunchSeconds, PerchSeconds}`, `FMars_Bat_Timing {HitSeconds, StunSeconds,
     RoostIdleSeconds...}`, `TArray<FVector> FlightNodes` (authored patrol nodes), `FCk_Handle_VoxelNavVolume
     Volume` (or the volume is discovered by entity tag - pick one and document), `FMars_Monster_Spec Monster`.
     `mixin FMars_Validation Validate(const FMars_Bat_Spec& Self)`. Fragments: `FMars_Fragment_Bat_Params`,
     `FMars_Fragment_Bat` (Phase, PhaseClock, Target, RouteStatus/last outcome, swoop ledger, roost claim state,
     telemetry for presentation: `Speed`, `SignedTurnRate`, `Pitch`), `FMars_Fragment_Bat_Requests` (TArray per kind),
     `FMars_Fragment_Bat_Signals` (`OnPhaseChanged`, `OnSwoopLanded`, `OnSwoopCancelled`, `OnRouteOutcome`,
     `OnPerchLost`, `OnTargetChanged`), tags `FMars_Tag_Bat_NeedsSetup`.
   - `Mars_Bat_Utils.as`: `utils_bat::Add(FCk_Handle_Transform& InRoot, FMars_Bat_Spec)` (composes monster, dealer,
     hurtbox, crowd agent, velocity/acceleration/integrator, voxel path, fragments, HFSM last); mixins
     (`Get_Phase`, `Get_Target`, `Get_IsSwoopCommitted`, `Get_RouteOutcome`, `Get_Telemetry`, `Get_MouthLocation`...),
     request mixins taking request structs.
   - `Mars_Bat_Processor_Requests.as` (`UMars_Processor_Bat_HandleRequests`: snapshot -> TryRemove -> apply in
     documented order -> broadcast), `Mars_Bat_Processor_Setup.as` (binds Health/Monster/agent/path signals into
     requests), `Mars_Bat_Processor_Targeting.as` (sense interval scan), `Mars_Bat_Processor_Tick.as` (phase clocks,
     swoop sweep + ledger, telemetry from the agent's velocity, death fall integration with a Jolt raycast to find the
     landing point - see `utils_jolt_static_world::Get_RayCastStaticWorld`/probe utils; stop on contact -> Landed).
   - `Mars_Bat_Hfsm.as` (control layer; CkStateMachine classes as in `Mars_Crawler_Hfsm.as`): `UMars_SmState_Bat_Alive`
     with a behaviour sub-SM Roost -> Alert -> Launch -> Patrol/Approach -> Telegraph -> Swoop -> Recover -> Return ->
     Brake -> Perch -> Roost, interrupts Hit and Stunned, and `UMars_SmState_Bat_Dead` (Die task: cancel swoop, stop
     and disable agent, disable zone, release roost claim exactly once, DeathFall -> DeathLand, despawn timer).
     Tasks issue kernel requests only; conditions poll kernel state or use the ByteAttribute Dead condition
     (`Script/Hfsm/Conditions/Mars_Hfsm_Condition_ByteAttribute.as`).
   - Hand-add `FCk_Handle_Bat` to `Script/Generated/DynamicHandleTypes.json` (format: see the `FCk_Handle_Monster`
     entry; alphabetical; Description must match the asset's). Register any new tags (`Monster.Mars.Bat`,
     `ByteAttribute...` if needed) in `Config/DefaultGameplayTags.ini` ONLY if the existing features do so by hand -
     check how `Monster.Mars.PickleMimic` / `Monster.Mars.RootMaw` were added and mirror it exactly.
2. `Script/WorldObjects/Monsters/Mars_CellarBat_EntityScript.as` (assembly): `UMars_CellarBat_EntityScript :
   UCk_GenericEntityScript_UE` with `ExposeOnSpawn` `SpawnTransform`, `FMars_Bat_Spec Spec`, `bool WithVisuals = true`,
   soft refs `TSoftObjectPtr<USkeletalMesh> Mesh` and `TSoftClassPtr<UAnimInstance> AnimClass` defaulting to
   `/Game/ArtCandidates/CellarBat/R01/Meshes/CellarBat_R01_Mars_SK` and
   `/Game/ArtCandidates/CellarBat/R01/Animation/CellarBat_R01_Mars_ABP.CellarBat_R01_Mars_ABP_C` (these do not exist
   yet: when `WithVisuals` is true and the load fails, fall back to a visible placeholder - a scaled engine cube or
   sphere body + two flat wing planes on the scene node - and log once at Warning). Composition: `Request_OverrideToSelf`
   first (see crawler), transform, `utils_bat::Add`, scene node + `USkeletalMeshComponent` via `utils_unreal_component`
   (pattern: `Script/WorldObjects/Steward/Mars_Steward_EntityScript.as` lines ~287-360), `SetAnimInstanceClass` in
   OnAdded (pattern: `Script/PlayerCharacter/Mars_PlayerCharacter.as:174,197`), a tick that pushes `Phase/Speed/
   SignedTurnRate/Pitch` into a `UMars_CellarBat_AnimInstance : UAnimInstance` (new file beside it; `BlueprintReadOnly`
   vars `Phase (int or enum)`, `Speed`, `TurnRate`, `BankAlpha (-1..1)`, `Pitch`, `IsFlying`), hanging orientation
   while roosting (rotate the presentation node, never the root transform), mouth/perch sockets by name when the mesh
   has them. Also `UMars_BatRoost_EntityScript` (a perch bar: transform + a simple mesh part + `TAG_MarsBatRoost`
   entity tag; the bat's `PerchOwner` can be this entity) and `UMars_BatFlightVolume_EntityScript` (transform +
   `utils_voxel_nav_volume::Add` from an `FBox` spec with `_ClearanceUu = AgentRadius`, `TAG_MarsBatFlightVolume`,
   build on setup; the bat kernel discovers it by tag if `Spec.Volume` is invalid and waits for `Get_IsBuilt`, reporting
   `NoBake` while it is not).
   Add sandbox presets in a NEW file `Script/WorldObjects/Monsters/Mars_SandboxBat.as` following the
   `Mars_SandboxMonsters.as` subclass pattern (do not edit that file).
3. `Script/Editor/Mars_CellarBat_MapBuilder.as` (`#if EDITOR`): console command `Mars.CellarBat.BuildReviewMap` that
   creates/opens the owned map `/Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP` (use
   `utils_mars_map_builder` helpers from `Script/Editor/Mars_MapBuilder_Utils.as`; if they assume the Sandbox map, add a
   small owned helper rather than editing them) and places: a 2000x2000 floor, walls/ceiling (BlockAll statics so Jolt
   LiveExtract bakes them), a perch beam near the ceiling with a `UMars_BatRoost_EntityScript`, a pillar obstacle
   between perch and dummy, a `UMars_TargetDummy_EntityScript` (hostile team), the flight volume entity covering the room,
   the bat spawner with FlightNodes around the room, a player start and a neutral + amber/teal light rig (reuse the
   values in `Tools/Blender/mars_monsters/pale_crawler_r01/pale_crawler_ue.py` AMBER/TEAL). Save only that map.
4. `Script/Tests/Bat/`: `Mars_AutoTestRig_Bat.as` (pattern `Script/Tests/RootMaw/Mars_AutoTestRig_RootMaw.as`: Jolt
   floor via `utils_jolt_body`, a hostile target with Health/HitZone/hurtbox/`TAG_MarsCombatTarget`, the flight volume
   with a small bounds box and a WaitUntil on `Get_IsBuilt`, spawn via `UMars_CellarBat_EntityScript::Params()` with
   `WithVisuals = false`, isolated `_Origin`), and focused tests (`default _TimeoutSeconds` generous, bake takes frames):
   - `Mars_AutoTest_Bat_RoostsAlertsLaunchesAndSwoopsOnce` - full happy path to exactly one `OnDamaged` on the target,
     and no second hit during Recover/Return.
   - `Mars_AutoTest_Bat_CancelBeforeCommitDealsNothing` - cancel during Telegraph; zero damage; phase returns to flight.
   - `Mars_AutoTest_Bat_DeathDuringSwoopCancelsAttack` - kill mid-swoop; zone disabled, no damage after, agent stopped,
     Falling -> Landed, despawn after corpse seconds, roost claim released once (assert a counter == 1).
   - `Mars_AutoTest_Bat_BlockedRouteReportsOutcomeAndReturnsHome` - wall the goal off with a Jolt static box before
     the bake; expect an explicit route outcome (`Unreachable` or GoalBlocked) and a Return/Hover phase, no teleport.
   - `Mars_AutoTest_Bat_LostTargetAndInvalidPerchHaveOutcomes` - destroy the target mid-approach -> `TargetLost`
     cancel and Return; destroy the perch owner -> `OnPerchLost` and a safe hover phase, never a landing.
   - `Mars_AutoTest_Bat_TeardownReleasesBindingsOnce` - destroy the bat entity in flight; no ensure, no dangling
     timers, claim released once.
   Tests use `Add_Step_WaitUntil` / `Add_Step` / `Assert_True` as in `Mars_AutoTest_RootMaw_DiesAndSinksBackIn.as`.

## Build/test rules (test-only path; the editor stays open)

- Classification: AngelScript + content only -> no C++ build. Use the toolbox test-only path from
  `CkAuto/.claude/skills/build-test/SKILL.md`:
  `Set-Location "D:\Repositories\CkRepos\Orion"; ./CkAuto/UnrealToolbox.exe --test --test-pattern <Pattern>
  --output=Saved/Logs/Test-Bat.log --project="D:\Repositories\CkRepos\Orion"` (PowerShell tool; run in background
  with a long timeout and wait for completion; read the final summary block and the real exit code).
- BEFORE your first `Script/` edit: run `--test-pattern Monster` once as the baseline and record the pass/fail names
  and the `=== Known reds ===` block in PROGRESS.md.
- Quiescence protocol: never save a `.as` edit while a toolbox run is in flight (the live editor regenerates
  `Script/Generated/*` and contaminates the run). Check the live editor log tail has settled (no AngelScript compile
  errors: `Saved/Logs/Mars.log`) after each batch of edits before launching a run; fix compile errors it reports.
- Iterate with `--test-pattern Bat`; finish with `--test-pattern Bat` AND `--test-pattern Monster` green (or explain
  every red by name against the baseline). Focused results are labelled focused. Do NOT run the full gate.
- Never add a `knownReds` entry. Never edit `AutomationGate.json`.
- Generated files (`Script/Generated/Mars_EntitySpawnParams.as`, `Mars_AutoTestActors.as`,
  `Mars_ScriptProcessorDrivers.as`) regenerate from the live editor; do not hand-edit them, and do not stage/commit
  anything (no git state changes at all).
- Monolith (`mcp__monolith__editor_query`) may be used read-only (logs: `tail_log`, `search_logs`; `run_python` only to
  read state) and to run the review-map console command / save the owned map. Do not start PIE in this phase (the
  Blender track imports assets through the same editor; PIE blocks imports). PIE review is Phase 6b.

## Hard rules

- New files only, except: `Script/Generated/DynamicHandleTypes.json` (one entry) and the tags ini if that is the
  established registration path. Do not edit Crawler/Monster/RootMaw/TargetDummy/SandboxMonsters files.
- Conventions from root CLAUDE.md are mandatory: request doctrine (only processors write fragments; HFSM tasks issue
  requests), `utils_bat` only, <= 3 params, `Validate()` mixin wrapped in `ck::EnsureIfNot` in `Add`, no strong UObject
  refs in fragments, ids as gameplay tags, `TOptional` for absent values, ensures over silent returns, enums over bools.
- Keep the attack authorization and movement decisions in the kernel/HFSM; the AnimInstance only reads telemetry.
- Timings and speeds are Spec fields (editable configuration), with sensible defaults documented in the Spec.
- Update `PROGRESS.md` (Phase 6a section): files, commands run, baseline and final focused results by name with exit
  codes, open blockers. Mark claims confirmed/inferred.

## Reporting back

Files created (paths), the exact toolbox commands and their exit codes, baseline vs final test names, how the swoop
ledger guarantees one hit, which outcomes are explicit, what is placeholder pending the mesh/AnimBP, and anything
unverified.
