# Phase E brief - grip points: one producer, one consumer, for every item kind

Maintainer direction (2026-11-06): grips should be target points (entities with a transform) attached to whatever the
visual is (static, skeletal, other). "We always aim for correctness and solid (and hard to misuse) interfaces, no
shortcuts or hacks. If we need to improve existing models let's do it." This phase makes an item's grips declared in
ONE place, produced by ONE piece of code, and consumed by ONE resolution path for reach and hold. Read first:
`PROGRESS.md` (Phase 1 + D sections), then every file below.

## What exists (confirmed by reading; re-verify lines)

- Grip table: `FMars_FPHands_GripEntry { Hand; Node (FCk_Handle_Transform); TOptional<FName> Socket; Pose;
  ReachOverrideCm; Frame (Aimed | Node); Roll }`, `FMars_Fragment_FPHands_Grips { Entries }`,
  `utils_fphands::Add_Grips(owner, entries)` (all-or-nothing) - `Script/ECS/FPHands/Mars_FPHands_Grips.as:92-160, :341`.
  Users: `Script/WorldObjects/Stations/Mars_Station_EntityScript.as:72` and two FPHands tests.
- Reach: `Resolve_ReachTarget_AsAuthored` (`Mars_FPHands_Grips.as:~605`) returns `Resolve_GripTable(...)` when the
  owner has the Grips fragment (:620), before the item branch (:646, `Find_MeshSockets(UStaticMesh)` from the
  definition's `Visual.Mesh`) and the object-socket branch (:706, `Find_EntitySockets` / `Find_ActorSockets`).
  `Resolve_GripTable` never fills `Target.Pickup` (`FMars_FPHands_PickupFacts { IsSet; Shape }`), which
  `Mars_FPHands_Contact.as:118` (finger-close shape) and `Mars_FPHands_Processor_Requests.as:109, :258` (pickup gating)
  read. So an item with a table is reached like a lever today.
- Hold: `utils_fphands::Make_Hold(item)` (`Script/ECS/FPHands/Mars_FPHands.as:516-577`): Bounds from the persistent
  world item's BoundsFit (else `Make_BoundsFit(Presentation)`), Faces from `Grip.HalfWidth` or `Measure_Faces(UStaticMesh)`,
  `SocketGrips` ONLY from `Find_MeshSockets(UStaticMesh)` then `Twist_AboutHandle(grip, SocketTwist_R/_L) * HeldOffset`.
  `SocketGrips` feed the glove targets and `Script/PlayerCharacter/Chef/Mars_HeldView.as` (`SocketGrip_R/_L`); tests in
  `Script/Tests/HeldView/`, `Script/Tests/FPHands/` (`SocketGripFollowsMovingPart`, `GripTableGivesEachHandItsOwnAnchor`,
  `AOneHandedPickupReachesWithTheGloveThatHoldsIt`, `PoseOverrideAppliesOnlyWhileReaching`).
- Item definition: `Script/Items/Traits/Mars_ItemTrait_Presentation.as` - `FMars_ItemPresentation_Grip { Pose; Layout
  (Sides | Cradle); Handedness; TOptional<float32> HalfWidth; Shape; SocketTwist_R; SocketTwist_L }`, `Validate()`.
- Socket-authored items: `Script/Items/Mars_Item_Sandbox.as:76, :112` (cleaver, tenderizer: `Grip_R/Grip_L` on the SM
  + twists), Cookbook (`SM_Cookbook_Closed`). Mechanisms with sockets on their own meshes: `Mars_HandWheel_EntityScript.as:73`,
  `Mars_ChainBridge_EntityScript.as:186`, lever (`LeverHandle_Mars_SM`, `Grip`) - these are NOT items and keep the
  object-socket branch (out of scope unless it falls out for free).
- WorldItem base: `Script/WorldObjects/Items/Mars_WorldItem_EntityScript.as` (`AddVisual` :276 creates `WorldItem_Mesh`
  in BOTH World and Visual mode; `OnMeshComponentAdded` :367; `DoOnVisualMeshAdded` hook; `DoConstruct` :76).
  Transient items held in the hand are a Visual-mode world item (`EMars_WorldItem_Mode::Visual`,
  `HeldItem.PresentationEntity`); persistent ones are the World-mode entity itself.
- Phase D's turnip (`Mars_ScreamingTurnip_EntityScript.as`, `Mars_Item_ScreamingTurnip.as`) is the first skeletal
  consumer. Its grip positions come from the Phase A landmark table (`review/phaseA/measurements.json`, `Grip_L/Grip_R`
  relative to the root; until Phase A lands, the proxy's lower flanks at about y = +-4.5 cm, z = 3.5 cm).

## Design (decided; implement exactly, raise a flag with evidence if the code refuses)

1. **Declaration lives in the definition.** `FMars_ItemPresentation_Grip` gains `FMars_ItemPresentation_GripPoints
   { TOptional<FTransform> Right; TOptional<FTransform> Left; }` (root-relative, cm, unit scale: the item's own frame,
   the same frame `HeldOffset` and the body use). `Validate()`: Left set requires Right set; TwoHanded requires both
   or neither; OneHanded forbids Left; a point with a non-unit scale is invalid. `SocketTwist_R/_L` stay as the twist
   applied to points that come from mesh sockets (authoring convenience); they are NOT applied to explicit points
   (an explicit point already states its rotation). Document both rules on the fields.
2. **One producer: the WorldItem base.** At construction, in BOTH modes (World and Visual), the base resolves the
   item's grip points in this order and registers them ONCE with `Add_Grips` as `Frame = Node`, `Roll = Fixed`, the
   presentation's pose: (a) the definition's explicit points; (b) else sockets `Grip_R` (or `Grip`) / `Grip_L` on the
   visual mesh ASSET (`UStaticMesh.FindSocket`; `USkeletalMesh` sockets when a subclass reports a skeletal visual - add a
   small `protected` hook that returns the socket transforms, default static) with `SocketTwist_*` applied and
   `MeshScale` applied once; (c) else nothing (fitted Sides/Cradle layout as today). The nodes are scene nodes under the
   root at the resolved transforms (a static-mesh socket's transform is read from the asset, so no dependency on the
   async component). Subclasses NEVER call `Add_Grips` for an item; remove any such call Phase D added and route the
   turnip through (a). `Find_MeshSockets` and `Measure_Faces(UStaticMesh)` are called from the producer only.
3. **One consumer.** Reach: an item owner (has `FMars_Fragment_WorldItem_Params`) resolves through its grip table and
   fills `Target.Pickup` (IsSet, Shape from the presentation: mesh if any, scale, grip shape; mesh-less -> the BoundsFit
   shape the reach-hint branch builds), ContactPose, Layout Authored; with no table it takes the fitted branch
   (reach hint / Sides). Delete the item static-socket branch at :646. Hold: `Make_Hold(item)` takes `SocketGrips` from
   the grip nodes of the item's current presentation entity (persistent world item, or the Visual-mode entity the held
   item spawned - find the right accessor; `HeldItem.PresentationEntity` is the candidate), each node's transform
   relative to the item root composed with `HeldOffset`, Kind from the entries present; with no nodes it keeps the
   fitted Faces path. Delete the `Find_MeshSockets` call from `Make_Hold`. HeldView is unchanged.
4. **Equality, proven.** The cleaver (or tenderizer) result through the old socket path is captured BEFORE the change,
   in a test, as named constants (SocketGrips R/L transforms, Kind, reach target transforms), and the new path must
   reproduce them within 0.001 (the HeldView tolerance). If a socket item's result cannot be reproduced because the
   old path was itself wrong (e.g. twist applied in a different frame), say so with numbers and fix the MODEL or the
   definition rather than special-casing the code; record it as a deviation.
5. **Turnip adopts it.** `Mars_Item_ScreamingTurnip.as` declares `Grip.Points` (Cradle pose, two points) from the Phase
   A table; the entity script keeps no grip code. Record the transforms used.

6. **Base body hook, no duplicated construction (Phase D audit item).** `UMars_WorldItem_EntityScript::AddBody` is
   private, so Phase D's `Mars_ScreamingTurnip_EntityScript.as` re-implements the whole World-mode `DoConstruct` and
   copies the base body tuners (mass, damping, friction, restitution, profile) to add `Set_PersistContacts(Enable)`.
   Replace that with a protected hook on the base, e.g. `protected void DoConfigure_BodySpec(FCk_JoltBody_Spec& InOutSpec)`
   (default no-op, called by the base `AddBody` after its own settings and before `utils_jolt_body::Add`), and return
   the turnip to `Super::DoConstruct` + the hook + `DoOnVisualMeshAdded` (hide the proxy once the skeletal mesh loads)
   + composing the kernel and presentation after the base ran. Delete `AddTurnipProxy` / `AddTurnipBody` and the
   copied constants. The body must still report persisted contacts (test 1 proves it).
7. **`EMars_Interactable_DisableReason::Exhausted` (Phase D audit item).** The bed disables its target with `Ledger`
   because no exhausted reason exists (D-D3). Add `Exhausted` to the enum in `Script/ECS/Interactable/
   Mars_Interactable_Feature.as` (document it: the source holds no charge any more), update every switch/lookup over
   the enum, and use it in the bed's `Claim_Target` and pull task.

## Deliverables

- Code: `Mars_ItemTrait_Presentation.as` (points + Validate), `Mars_WorldItem_EntityScript.as` (producer + hook + body hook),
  `Mars_Interactable_Feature.as` (one enum value) and its lookups,
  `Mars_FPHands_Grips.as` (consumer reach), `Mars_FPHands.as` (consumer hold), turnip def/entity script, and the
  socket items' definitions only if (4) proves a model/definition fix is needed.
- Tests (new files under `Script/Tests/FPHands/` and `Script/Tests/WorldItem/`):
  `Mars_AutoTest_FPHands_AGripPointItemIsReachedAsAPickup`, `Mars_AutoTest_FPHands_GripPointsGiveTheHeldSocketGrips`,
  `Mars_AutoTest_WorldItem_MeshSocketsBecomeGripPoints` (cleaver-style: nodes' world transforms equal the asset
  sockets'; Make_Hold equals the captured pre-change constants), `Mars_AutoTest_WorldItem_GripPointsValidate`
  (the Validate rules above), `Mars_AutoTest_FPHands_ATransientHeldItemResolvesGripPoints` (Visual-mode entity).
- Gates (test-only path beside the open editor, quiescence protocol): before the first edit capture `FPHands`,
  `HeldView`, `WorldItem`, `HeldItem` (counts + failing names); iterate on the new tests; finish with those four plus
  `ScreamingTurnip`, `Cookbook`, `Searing` (held cleaver/tenderizer live there) and `Stations`. No full gate, no `Mars`
  lane. Any NEW failure: solo re-run and attribute.
- `PROGRESS.md` Phase E section: resolution table before/after per item kind (static with sockets, static without,
  skeletal, procedural/transient), the producer order, gates, deviations, not verified (PIE look in the gloves).

## Hard rules

- Files you may edit: the code files above (incl. `Mars_Interactable_Feature.as` for the one enum value and the
  files that switch over it), the turnip files from Phase D (entity script, bed, def, presentation), item definitions
  ONLY under rule (4), new tests. The FPHands / WorldItem files carry the maintainer's uncommitted ride-home work: edit additively, never
  revert a hunk you did not write, no git operations. Nothing else (no other dirty path, no submodule, no live map, no
  Content/ writes - a model fix under (4) is proposed in PROGRESS.md with the exact socket change, not applied to the
  asset by you).
- No parallel declaration paths survive: after this phase an item's grips are `Grip.Points` or mesh sockets resolved
  by the producer, nothing else; no subclass `Add_Grips`, no second socket reader. A mechanism's object-socket branch
  stays (not an item).
- Mars conventions (request doctrine, <= 3 params, TOptional over sentinels, brace layout, `.As_X()` casts, no strong
  UObject refs in fragments, `Validate()` mixins). No sleeps/retries/guards; no "fall back to the old path for one
  frame" - the producer reads the asset synchronously so the table exists before the first reach.
- Start only after Phase D has reported (its lanes must not overlap yours).

## Reporting back

Files; the resolution table before/after; the producer order and the hook signature; the turnip's grip points; the
captured cleaver constants and the equality result; gate results per pattern with counts, failing names and solo
verdicts; deviations; what remains unverified. Confirmed vs inferred on every claim.
