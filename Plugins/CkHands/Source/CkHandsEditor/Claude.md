# CkHandsEditor

Editor half of CkHands (UncookedOnly): the anim graph node for Glove Placement and editor scripting for wiring Ck Hands
rigs into anim blueprints.

## Key API

- `UCk_AnimGraphNode_Hands_GlovePlacement` — the graph node for `FCk_AnimNode_Hands_GlovePlacement`. At anim
  blueprint compile it errors when `PlacedBone` or `TargetBone` is missing from the skeleton or `TargetBone` is not a
  descendant of `PlacedBone`; the runtime node checks nothing beyond `IsValidToEvaluate`.
- `UCk_Utils_HandsEditor_UE::Request_SetControlRigNodePinExposed(AnimBlueprint, NodeName, VariableName,
  ECk_EnableDisable)` -> `ECk_SucceededFailed` — shows (Enable) or hides (Disable) a Control Rig variable as an input
  pin on a Control Rig anim node (its "Use Pin" checkbox), from Blueprint, Python or AngelScript. `NodeName` is the
  graph node's object name (e.g. `AnimGraphNode_ControlRig_0`).
  - Atomic: validates the blueprint, that exactly one node has that name and that it is a Control Rig node, that the
    variable is one the node can expose (asked of the engine's own `FControlRigIOMapping`: a public, writable variable
    of the rig class) with a pin type, and that the node's pin list is reachable; any failure ensures, changes nothing
    and returns Failed.
  - Already in the requested state: Succeeded, no transaction.
  - Otherwise one undoable transaction: `Modify`, the `SetCustomPinVisibility` sequence (cache shown pins, set
    `bShowPin`, mark a hidden pin as not saved when orphaned, reconstruct), then the blueprint is marked structurally
    modified.

## Anti-patterns

- Toggling `CustomPinProperties` by hand elsewhere: it is protected engine state; go through this utility so the
  orphan-pin handling and the transaction stay correct.
- Assuming a curve mapping is cleared: the engine's own checkbox also clears an input curve mapping for the variable
  when the pin is exposed. This utility cannot reach that private map and leaves it as it is.

## Diagnostics and tests

No automation: both pieces need an anim blueprint asset (and the utility a Control Rig asset). [EDITOR-VERIFY] steps
belong with the consumer that wires them (open the anim blueprint, run the utility from Python, check the pin appears
and undoes in one step).

## Boundaries

Depends on CkHands, CkCore, CkLog and the engine animation, Control Rig and RigVM editor modules. Never linked by
runtime code.
