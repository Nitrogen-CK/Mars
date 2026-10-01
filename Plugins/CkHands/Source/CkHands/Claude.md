# CkHands

Procedural hands: a Control Rig node that curls each digit onto what the hand holds, an anim graph node that places a
floating hand on a grip target, and the world-free math under both. Game-agnostic; nothing here knows about items,
characters or ECS entities.

## Key API

- **Data** (`CkHands_Contact_Data.h`)
  - `FCk_Hands_ContactShape` — `_Type` (`ECk_Hands_ContactShapeType`: Box, Sphere, Capsule, None), `_Transform`,
    `_HalfExtents` (Box), `_Radius` (Sphere, Capsule), `_HalfHeight` (Capsule). Expressed in the space of the pose being
    solved (component space for both nodes). Only the rotation and translation of `_Transform` are used; scale is
    ignored. A Capsule's cylinder section runs along its local **Z**, `_HalfHeight` each side of the origin (the
    cylinder section only, as UE capsules and `FCk_Jolt_ShapeDimensions` define it).
  - `FCk_Hands_DigitContactSettings` — `_Radius` (digit thickness, sample spacing and per-step travel bound, cm),
    `_MaxSearchSteps`, `_TipLengthRatio`.
- **Kernel** (`CkHands_Kernel.h`, `namespace ck::hands`; world-free, thread-safe, no UObject access)
  - `Get_IsShapeValid`, `Get_IsSettingsValid`, `Get_SignedDistance` (GeometryCore `TOrientedBox3` / `TSphere3` / `TCapsule3`, negative
    inside, `TNumericLimits<double>::Max()` for None), `Get_ShapeInSpace` (rigid change of space). The last two are
    the hot path: they take a valid shape as a precondition and do not validate it.
  - `Solve_DigitCurl` — how far (0..1) a digit can curl from rest toward its target pose before it newly touches the
    shape. The header documents the sampling, the adaptive step count and the exact no-tunnelling guarantee.
  - `Get_GlovePlacement` — the placement math of the anim node.
- **Utils** (`CkHands_Utils.h`; Blueprint and AngelScript): `UCk_Utils_Hands_ContactShape_UE` (`ScriptMixin` on
  `FCk_Hands_ContactShape`: `Make_Box` / `Make_Sphere` / `Make_Capsule`, `Get_IsValid`, `Get_SignedDistance`,
  `Get_InSpace`) and `UCk_Utils_Hands_UE` (`ScriptMixin` on `FCk_Hands_DigitContactSettings`: `Get_IsSettingsValid`;
  plus `Solve_DigitCurl`). Wrappers over the kernel, and the Blueprint/AngelScript validation boundary: an invalid
  shape ensures in every wrapper. A maker that would build an invalid shape returns a None shape; `Get_SignedDistance`
  returns `TNumericLimits<double>::Max()` (as for None); `Get_InSpace` returns the input unchanged; `Solve_DigitCurl`
  ensures in the kernel and returns 1.
- **Contact Curl (Ck Hands)** — `FCk_RigUnit_Hands_ContactCurl` (`Rig/`), Control Rig. One node per digit: `Items` is
  the digit's bone chain, root first; the root's parent is the hand. Curls the digit from its initial (rest) pose
  toward the pose it came in with and stops where it first newly touches `Shape` (rig global space). A None shape skips
  the solve (the incoming pose). Invalid `Settings` are authoring state: reported on the node, the solve is treated as
  1 (the digit eases to its incoming pose) and the kernel is not called. An invalid `Shape` is runtime data from the
  game and ensures in the kernel. The curl eases toward the solved value at `InterpSpeed` (1/s, 0 snaps; the first
  evaluation, and any with a zero delta time, snaps).
- **Glove Placement (Ck Hands)** — `FCk_AnimNode_Hands_GlovePlacement` (`AnimNode/`), anim graph, component space.
  Moves a floating hand rigidly by `PlacedBone` so that `TargetBone` (a descendant) lands exactly on `Target`. The
  offset comes from the incoming pose; `Target`'s scale is ignored and `PlacedBone` keeps its own scale.

## Anti-patterns

- Passing a world-space shape to either node. Re-express it with `Get_InSpace` (component space = the mesh
  component's world transform).
- Expecting the curl to push a digit out of something it already touches at rest: contact that existed at rest is
  ignored by design (a handle through the palm must not stop the fingers).
- Reading the capsule axis as local X (the pre-rename convention). It is local Z.
- Relying on the tunnelling guarantee with a clamped step count: with a fast, long digit and a small `_Radius`,
  raise `_MaxSearchSteps` or accept a coarser search.
- Wrapping kernel calls in `ensure`/early-outs: invalid kernel input already ensures once and recovers with 1.

## Diagnostics and tests

- Contract violations in `Solve_DigitCurl` (rest/pose count mismatch, fewer than 2 segments, invalid shape, invalid
  settings, non-finite transforms) fire `CK_ENSURE_IF_NOT` and return 1. A None shape is a fast path, not an error.
- Contact Curl reports authoring states on the node (`UE_CONTROLRIG_RIGUNIT_REPORT_WARNING`): fewer than two items or
  an item missing from the hierarchy (it writes nothing), invalid `Settings` (the digit eases to its incoming pose, no
  ensure). A missing rig hierarchy and an invalid `Shape` ensure.
- The Utils wrappers ensure on an invalid shape (see Key API for each recovery).
- `ShowDebug Animation` lists Glove Placement with its bones and recurses into its input.
- C++ automation, root `CkHands.` (flags `ck::hands::tests::kCkUnitTestFlags` in `CkHands_UnitTest_Common.h`):
  `CkHands.Kernel.*` (`CkHands_Kernel.spec.cpp`), `CkHands.Utils.*` (`CkHands_Utils.spec.cpp`) and `CkHands.RigUnit.*` (`Rig/CkHands_RigUnit_ContactCurl.spec.cpp`,
  a hand-built `URigHierarchy`; no world). The anim node has no spec of its own: evaluating it needs an
  `FAnimInstanceProxy` and a skeleton-backed `FBoneContainer`; its math is covered by
  `CkHands.Kernel.GlovePlacement_LandsTargetBoneOnTarget`.

## Boundaries

Depends on CkCore and CkLog only (plus engine animation and Control Rig modules; GeometryCore privately). No ECS, no
CkGameplayDebugger. Editor-only pieces (the anim graph node and editor scripting) live in `CkHandsEditor`.
