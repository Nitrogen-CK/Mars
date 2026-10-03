# CkHands

Procedural hands: Control Rig and anim graph nodes that make hands close on what they hold and place floating hands on
grip targets. Game-agnostic; Mars's first-person gloves are the first consumer (the `Script/ECS/FPHands` feature builds
the contact shapes, `Script/PlayerCharacter/FPHands/Mars_FPHands_AnimInstance.as` hands them and the grip targets to
`ABP_FPHands` / `CR_FPHands_Contact`), and the same nodes are meant for full-body characters with the same hand rig.

Follows the CkFoundation doctrine (`Plugins/CkFoundation/CLAUDE.md`). Reflected rig-unit and anim-node members keep
plain engine-style names (they are the pin names and the `StaticExecute` parameter names), not `_PascalCase`.

## Modules

| Module | Type | Contents | Docs |
|---|---|---|---|
| `CkHands` | Runtime | Contact data, the world-free kernel (`ck::hands`), Utils, the Contact Curl Control Rig node (`Rig/`), the Glove Placement anim node (`AnimNode/`), C++ specs | [Source/CkHands/Claude.md](Source/CkHands/Claude.md) |
| `CkHandsEditor` | UncookedOnly | The Glove Placement anim graph node, `UCk_Utils_HandsEditor_UE` editor scripting | [Source/CkHandsEditor/Claude.md](Source/CkHandsEditor/Claude.md) |

## Wiring into an anim blueprint

Run placement before the rig so the rig sees where the hands really are:
`... -> Local To Component -> Glove Placement (L) -> Glove Placement (R) -> Component To Local -> Control Rig (Contact Curl xN)`.
Give the rig one public `FCk_Hands_ContactShape` variable per hand (component space) and expose it as a pin on the
Control Rig anim node; `UCk_Utils_HandsEditor_UE::Request_SetControlRigNodePinExposed` does that from Python, Blueprint
or AngelScript.

## Tests

`CkHands.*` automation (the plugin name is the test root): `CkHands.Kernel.*`, `CkHands.Utils.*`, `CkHands.RigUnit.*`.
