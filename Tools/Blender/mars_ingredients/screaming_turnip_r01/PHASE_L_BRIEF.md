# Phase L brief - the gloves read their grip live: skeletal-mesh sockets as grip anchors, anchors resolved at composition time

You are an Opus executor for one part of Phase L. Read first: `PHASE_K_BRIEF.md` and the Phase K sections at the end of
`PROGRESS.md` (Part 2c's frame-order table is the ground truth for this phase), then `Script/ECS/FPHands/Mars_FPHands_Grips.as`
(the grip structs, `Make_EntryGrip`, `Find_EntitySocketComponent`, `Resolve_GripTable`, `Make_TargetReach`,
`Update_ReachTarget` / `Refresh_Anchor`, `Resolve_WorldGrip`), `Script/ECS/FPHands/Mars_FPHands.as` (`Apply_HandReach`,
`Make_LeanedGrip`), `Script/ECS/FPHands/Mars_FPHands_Processor_Tick.as`, `Script/PlayerCharacter/FPHands/Mars_FPHands_AnimInstance.as`
(composition at anim time), `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as` (`AddHarvestGrips`,
`DoMove_GripNode`, `OnFollowTick`), `Script/WorldObjects/Items/Mars_WorldItem_EntityScript.as` (the item grip producer) and
the FPHands tests (`Script/Tests/FPHands/`, the rig `Mars_AutoTestRig_Hands.as`, `SocketGripFollowsMovingPart`,
`GripTableGivesEachHandItsOwnAnchor`). Project rules are binding (`CLAUDE.md` Mars conventions; "a changed glove pose is
done only once it has been seen in PIE"). Maintainer: "best, most scalable, robust; no hacks or shortcuts; verify, don't guess".

## Why

After Phase K the planted turnip's pose is drawn on the same frame as the pull, but the gloves still sit on the previous
frame's stalk sockets (run-13: 0.000 cm to the previous tick's socket; 0.25 cm behind at 30 cm/s, up to 3.5 cm at a full
backward walk). Two causes, both in FPHands, both measured against the frame order Part 2c established:

1. `Resolve_WorldGrip` composes `WorldGrip = Grip * AnchorWorld`, and `AnchorWorld` is a copy refreshed in
   `UMars_Processor_FPHands_Tick` (FGroup_Gameplay_Script) from the anchor node's transform of that moment, i.e. before this
   frame's Transform pass and before the pose is evaluated (FGroup_PostTransform). The gloves are composed later still, in
   `UMars_FPHands_AnimInstance::BlueprintUpdateAnimation`, when the anchor's true transform is available. Every grip in
   the game reads a frame-old anchor.
2. A socket grip is resolved ONCE at reach start, relative to its node (`Make_EntryGrip`), and only static mesh components
   are searched (`Find_EntitySocketComponent`). A socket on a skeletal mesh that moves with its animation cannot be a grip,
   which is why the bed moves two scene nodes onto the stalk sockets every tick (another frame).

## Decisions (Fable)

### D-L1 Anchors are read at composition time; the cached world is the fallback for a dead anchor

`Resolve_WorldGrip` reads the anchor live: `utils_transform::Get_EntityCurrentTransform(HandGrip.Anchor)` when the anchor
is valid, else `HandGrip.AnchorWorld` (kept for a target that destroyed itself, as today). `Update_ReachTarget` /
`Refresh_Anchor` stay as the last-known updater and lose nothing. No other caller semantics change. This makes every grip
(levers, pickups, docks, the turnip) one frame fresher: it is a behaviour change for every glove pose and is PIE-gated.

### D-L2 A grip may be a socket on any mesh component, resolved live

- `FMars_FPHands_HandGrip` gains `FCk_Handle_UnrealComponent SocketHost` and `FName Socket` (unset/none = the node is the
  anchor as today). When `SocketHost` is set, `Resolve_WorldGrip` reads
  `Component.GetSocketTransform(Socket, RTS_World)` live (the component via `utils_unreal_component::Get_Component`; a host
  whose component is gone falls back to the cached `AnchorWorld` and is not an ensure) and composes
  `WorldGrip = Grip * SocketWorld`, where `Grip` is the authored handed frame IN THE SOCKET'S SPACE (identity = the socket's
  own axes are the grip, as every static-mesh grip socket is authored). Fragments hold handles, never the component.
- `Find_EntitySocketComponent` searches `UMeshComponent`s that carry the socket (static and skeletal), returning the
  component AND its owning Ck unreal-component handle (a small result struct; the 3-param rule). `Make_EntryGrip` for a
  socket entry fills `SocketHost`/`Socket` and `Grip = entry.SocketRotation (or identity)`; it no longer bakes the
  socket relative to the node. Static-mesh socket grips therefore also go live (their socket only moves with its node,
  so nothing visible changes for them beyond D-L1).
- `FMars_FPHands_GripEntry` gains `TOptional<FQuat> SocketRotation`: the handed grip rotation in the socket's frame, for
  sockets authored as positions only (the turnip's `HarvestGrip_*` have identity rotation on the crown); unset keeps the
  socket's own axes. Build it with `utils_fphands::Make_GripRotation`. Extend the positional constructor; the generator
  comment rule applies. `EMars_FPHands_GripFrame` is unchanged (it describes socketless entries).
- `Make_TargetReach`'s object-socket path (`Find_EntitySockets` / `Find_ComponentSockets`, levers and hand wheels) binds
  live the same way (host + socket, `Grip` identity, `Roll FaceViewer` as today) instead of baking the socket relative to
  the host at reach time. `Sockets.Host` already exists; add the socket names to `FMars_FPHands_MeshGrips`.
- The Place / Sides / point paths are untouched.

### D-L3 The bed authors its grips as skeletal sockets and stops moving nodes

`AddHarvestGrips`: two grip entries on the planted node (`_PlantedNode.As_Transform()`), `Socket` = `k_HarvestGripSocket_R / _L`,
`SocketRotation` = `Make_GripRotation(Right, +X fingers, -Y palm)` / `(Left, +X, +Y)` as authored today but now in the
socket's frame (the socket's axes are the crown's: verify the frame in PIE, and flip the fingers/palm vectors if the
gloves come out wrong - say which), Pose Power, Roll Fixed. The two `_HarvestGrip_*` scene nodes, `_HarvestGripRotation_*`,
`DoMove_GripNode` and the node moves in `OnFollowTick` go away; the follow tick keeps the turn toward the puller and its
end condition. `constants_screaming_turnip_assets::k_HarvestGripLocation_R / _L` lose their only reader: delete them (and
the manifest note that fed them) unless a test still reads them, in which case move the test to the socket. Since the
planted node is yawed toward the puller and the sockets are read in world space, no rotation bookkeeping remains.
The PIE driver's `grip_r/grip_l` node sampling (`screaming_turnip_walk_ue.py`) must switch to the sockets.

### D-L4 Tests (headless, lanes `FPHands`, `ScreamingTurnip`, `Control`, `WorldItem`, `Station`)

- `Mars_AutoTest_FPHands_ANodeAnchorIsReadLiveAtResolve`: a grip-table reach on a node; move the node and call the
  composition (`Get_HandTargets` or `Resolve_WorldGrip`) in the same step with no tick between: the world grip is at the
  new place; then destroy the node and resolve again: the last-known world is used (no ensure).
- `Mars_AutoTest_FPHands_ASkeletalSocketGripIsResolvedLive`: a scene node carrying a `USkeletalMeshComponent` with
  `ScreamingTurnip_R01_Mars_SK` (it loads headless: Phase K Part 2 showed the presentation's mesh loads in lanes) and a
  grip entry on `HarvestGrip_R` with a `SocketRotation`; move the node, resolve in the same step: the world grip equals
  `SocketRotation * socket world transform`; and with the component's pose changed (set the planted ABP's `CrownOffset`
  through the presentation component, or pose the bone through the anim instance if the ABP loads headless; else move the
  node again and say so) the grip follows the socket, not the node.
- `SocketGripFollowsMovingPart` and `GripTableGivesEachHandItsOwnAnchor` keep passing (their meaning is unchanged).
- ScreamingTurnip rig: whatever read `k_HarvestGripLocation_*` reads the socket now.

### D-L5 PIE proof (the gate for a changed glove pose)

run-14 on the review map from the 110 cm stand: glove-to-SAME-tick socket on both beds at 30 cm/s and at full speed
(expect 0.00x cm, the trail gone; report the max), the glove frame following the stalk's lean (capture at full strain,
first person, both hands visible on the stalks: fingers round the stalk, palm toward the crown - judge and say), the yaw
turn still carrying the grips (a sidestep), the cancel, 0 ensures. Then the regression look for every other grip, since
D-L1 freshens them all: a Sandbox or Warrens lever pull (a `Mars_Sandbox_PulledLever`), a one-handed pickup riding home,
a two-handed pickup, a dock/platter Place if one is on a reachable map: one capture each at the grip, "looks as before"
or the difference named. Nothing dirty outside the campaign's owned paths; the Sandbox is loaded read-only and NOT saved.

## Parts

- **Part 1 - Script** (one executor): D-L1..D-L4, lanes, `PROGRESS.md` Phase L Part 1 (re-read, one write). Report the
  exact struct/field names and the driver change the PIE part needs.
- **Part 2 - PIE** (one executor, after Fable's go): D-L5, the driver change, `PROGRESS.md` Phase L Part 2 + `VERIFICATION.md`
  L-rows.

## Hard rules

As every phase: Script/ only for Part 1 (no Generated/*, no tags ini); no git; no deletes of assets; toolbox lanes one at a
time, `--test --no-live --discover-fresh`, real `Passed:/Failed:` lines; never Plugins/CkFoundation; never minimize the
editor, never unload/reload, never Save All; the live editor hot-compiles Part 1 (expected). Final message per part:
files, rerun commands, numbers, what is unverified, confirmed vs inferred.
