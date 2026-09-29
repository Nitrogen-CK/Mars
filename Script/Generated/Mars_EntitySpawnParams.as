// Auto-generated EntityScript spawn-params - DO NOT EDIT.
// This file is regenerated on editor startup and after every AngelScript recompile.
//
// For each UCk_EntityScript_UE subclass, two declarations are emitted:
//   - FCk_MyEntityScript_SpawnParams  (file-scope USTRUCT, unique name - avoids the
//     `Params` name-collision across namespaces that trips the Unreal naming check)
//   - namespace UCk_MyEntityScript { FCk_MyEntityScript_SpawnParams Params() { ... } }
//     so callers can still write `UCk_MyEntityScript::Params()`.
//
// Properties are flattened across the hierarchy (AS has no struct inheritance). Non-
// trivial struct defaults outside the CkReflection_Utils allowlist are emitted without
// an initializer - set them on the instance before calling Request_SpawnEntity.

USTRUCT()
struct FCk_PlaceableTest_Cube_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    FCk_PlaceableTest_Cube_EntityScript_SpawnParams(FTransform InSpawnTransform)
    {
        SpawnTransform = InSpawnTransform;
    }
}

namespace UCk_PlaceableTest_Cube_EntityScript
{
    FCk_PlaceableTest_Cube_EntityScript_SpawnParams Params()
    {
        return FCk_PlaceableTest_Cube_EntityScript_SpawnParams();
    }

    FCk_PlaceableTest_Cube_EntityScript_SpawnParams Params(FTransform InSpawnTransform)
    {
        return FCk_PlaceableTest_Cube_EntityScript_SpawnParams(InSpawnTransform);
    }
}

USTRUCT()
struct FCk_PlaceableTest_Marker_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    FCk_PlaceableTest_Marker_EntityScript_SpawnParams(FTransform InSpawnTransform)
    {
        SpawnTransform = InSpawnTransform;
    }
}

namespace UCk_PlaceableTest_Marker_EntityScript
{
    FCk_PlaceableTest_Marker_EntityScript_SpawnParams Params()
    {
        return FCk_PlaceableTest_Marker_EntityScript_SpawnParams();
    }

    FCk_PlaceableTest_Marker_EntityScript_SpawnParams Params(FTransform InSpawnTransform)
    {
        return FCk_PlaceableTest_Marker_EntityScript_SpawnParams(InSpawnTransform);
    }
}

USTRUCT()
struct FCk_PlaceableTest_MeshComponent_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    FCk_PlaceableTest_MeshComponent_EntityScript_SpawnParams(FTransform InSpawnTransform)
    {
        SpawnTransform = InSpawnTransform;
    }
}

namespace UCk_PlaceableTest_MeshComponent_EntityScript
{
    FCk_PlaceableTest_MeshComponent_EntityScript_SpawnParams Params()
    {
        return FCk_PlaceableTest_MeshComponent_EntityScript_SpawnParams();
    }

    FCk_PlaceableTest_MeshComponent_EntityScript_SpawnParams Params(FTransform InSpawnTransform)
    {
        return FCk_PlaceableTest_MeshComponent_EntityScript_SpawnParams(InSpawnTransform);
    }
}

USTRUCT()
struct FCk_PlaceableTest_Sphere_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    FCk_PlaceableTest_Sphere_EntityScript_SpawnParams(FTransform InSpawnTransform)
    {
        SpawnTransform = InSpawnTransform;
    }
}

namespace UCk_PlaceableTest_Sphere_EntityScript
{
    FCk_PlaceableTest_Sphere_EntityScript_SpawnParams Params()
    {
        return FCk_PlaceableTest_Sphere_EntityScript_SpawnParams();
    }

    FCk_PlaceableTest_Sphere_EntityScript_SpawnParams Params(FTransform InSpawnTransform)
    {
        return FCk_PlaceableTest_Sphere_EntityScript_SpawnParams(InSpawnTransform);
    }
}

USTRUCT()
struct FMars_Gate_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate = FMars_Gate_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_Gate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Gate_EntityScript
{
    FMars_Gate_EntityScript_SpawnParams Params()
    {
        return FMars_Gate_EntityScript_SpawnParams();
    }

    FMars_Gate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Gate_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Lever_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Lever_Spec Lever = FMars_Lever_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    FText PromptText = FText::FromString("Pull lever");

    FMars_Lever_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Lever_Spec InLever, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Lever = InLever;
        Source = InSource;
        PromptText = InPromptText;
    }
}

namespace UMars_Lever_EntityScript
{
    FMars_Lever_EntityScript_SpawnParams Params()
    {
        return FMars_Lever_EntityScript_SpawnParams();
    }

    FMars_Lever_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Lever_Spec InLever, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        return FMars_Lever_EntityScript_SpawnParams(InSpawnTransform, InLever, InSource, InPromptText);
    }
}

USTRUCT()
struct FMars_MechanismDriver_EntityScript_SpawnParams
{
}

namespace UMars_MechanismDriver_EntityScript
{
    FMars_MechanismDriver_EntityScript_SpawnParams Params()
    {
        return FMars_MechanismDriver_EntityScript_SpawnParams();
    }
}

USTRUCT()
struct FMars_Sandbox_GateA_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate = FMars_Gate_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_Sandbox_GateA_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Sandbox_GateA_EntityScript
{
    FMars_Sandbox_GateA_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateA_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateA_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Sandbox_GateA_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Sandbox_GateB_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate = FMars_Gate_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_Sandbox_GateB_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Sandbox_GateB_EntityScript
{
    FMars_Sandbox_GateB_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateB_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateB_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Sandbox_GateB_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Sandbox_GateC_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate = FMars_Gate_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_Sandbox_GateC_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Sandbox_GateC_EntityScript
{
    FMars_Sandbox_GateC_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateC_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateC_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Sandbox_GateC_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Sandbox_LeverA_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Lever_Spec Lever = FMars_Lever_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull lever");

    FMars_Sandbox_LeverA_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Lever_Spec InLever, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Lever = InLever;
        Source = InSource;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_LeverA_EntityScript
{
    FMars_Sandbox_LeverA_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_LeverA_EntityScript_SpawnParams();
    }

    FMars_Sandbox_LeverA_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Lever_Spec InLever, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        return FMars_Sandbox_LeverA_EntityScript_SpawnParams(InSpawnTransform, InLever, InSource, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_LeverB_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Lever_Spec Lever = FMars_Lever_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull lever");

    FMars_Sandbox_LeverB_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Lever_Spec InLever, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Lever = InLever;
        Source = InSource;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_LeverB_EntityScript
{
    FMars_Sandbox_LeverB_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_LeverB_EntityScript_SpawnParams();
    }

    FMars_Sandbox_LeverB_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Lever_Spec InLever, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        return FMars_Sandbox_LeverB_EntityScript_SpawnParams(InSpawnTransform, InLever, InSource, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_SwitchC_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Switch_Spec Switch = FMars_Switch_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FText PromptText = FText::FromString("Press switch");

    FMars_Sandbox_SwitchC_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Switch_Spec InSwitch, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Switch = InSwitch;
        Source = InSource;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_SwitchC_EntityScript
{
    FMars_Sandbox_SwitchC_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SwitchC_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SwitchC_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Switch_Spec InSwitch, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        return FMars_Sandbox_SwitchC_EntityScript_SpawnParams(InSpawnTransform, InSwitch, InSource, InPromptText);
    }
}

USTRUCT()
struct FMars_SmCondition_AllTasksSucceeded_SpawnParams
{
}

namespace UMars_SmCondition_AllTasksSucceeded
{
    FMars_SmCondition_AllTasksSucceeded_SpawnParams Params()
    {
        return FMars_SmCondition_AllTasksSucceeded_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_AnyTaskFailed_SpawnParams
{
}

namespace UMars_SmCondition_AnyTaskFailed
{
    FMars_SmCondition_AnyTaskFailed_SpawnParams Params()
    {
        return FMars_SmCondition_AnyTaskFailed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_ByteAttribute_SpawnParams
{
}

namespace UMars_SmCondition_ByteAttribute
{
    FMars_SmCondition_ByteAttribute_SpawnParams Params()
    {
        return FMars_SmCondition_ByteAttribute_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_CrouchPressed_SpawnParams
{
}

namespace UMars_SmCondition_CrouchPressed
{
    FMars_SmCondition_CrouchPressed_SpawnParams Params()
    {
        return FMars_SmCondition_CrouchPressed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HasMoveIntent_SpawnParams
{
}

namespace UMars_SmCondition_HasMoveIntent
{
    FMars_SmCondition_HasMoveIntent_SpawnParams Params()
    {
        return FMars_SmCondition_HasMoveIntent_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IntentActive_SpawnParams
{
}

namespace UMars_SmCondition_IntentActive
{
    FMars_SmCondition_IntentActive_SpawnParams Params()
    {
        return FMars_SmCondition_IntentActive_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IntentPressed_SpawnParams
{
}

namespace UMars_SmCondition_IntentPressed
{
    FMars_SmCondition_IntentPressed_SpawnParams Params()
    {
        return FMars_SmCondition_IntentPressed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractableIsDisabled_SpawnParams
{
}

namespace UMars_SmCondition_InteractableIsDisabled
{
    FMars_SmCondition_InteractableIsDisabled_SpawnParams Params()
    {
        return FMars_SmCondition_InteractableIsDisabled_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractableIsEnabled_SpawnParams
{
}

namespace UMars_SmCondition_InteractableIsEnabled
{
    FMars_SmCondition_InteractableIsEnabled_SpawnParams Params()
    {
        return FMars_SmCondition_InteractableIsEnabled_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractableIsFocused_SpawnParams
{
}

namespace UMars_SmCondition_InteractableIsFocused
{
    FMars_SmCondition_InteractableIsFocused_SpawnParams Params()
    {
        return FMars_SmCondition_InteractableIsFocused_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractableIsNotFocused_SpawnParams
{
}

namespace UMars_SmCondition_InteractableIsNotFocused
{
    FMars_SmCondition_InteractableIsNotFocused_SpawnParams Params()
    {
        return FMars_SmCondition_InteractableIsNotFocused_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractedWith_SpawnParams
{
}

namespace UMars_SmCondition_InteractedWith
{
    FMars_SmCondition_InteractedWith_SpawnParams Params()
    {
        return FMars_SmCondition_InteractedWith_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IsDowned_SpawnParams
{
}

namespace UMars_SmCondition_IsDowned
{
    FMars_SmCondition_IsDowned_SpawnParams Params()
    {
        return FMars_SmCondition_IsDowned_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IsFalling_SpawnParams
{
}

namespace UMars_SmCondition_IsFalling
{
    FMars_SmCondition_IsFalling_SpawnParams Params()
    {
        return FMars_SmCondition_IsFalling_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IsGrounded_SpawnParams
{
}

namespace UMars_SmCondition_IsGrounded
{
    FMars_SmCondition_IsGrounded_SpawnParams Params()
    {
        return FMars_SmCondition_IsGrounded_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IsNotDowned_SpawnParams
{
}

namespace UMars_SmCondition_IsNotDowned
{
    FMars_SmCondition_IsNotDowned_SpawnParams Params()
    {
        return FMars_SmCondition_IsNotDowned_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_JumpHeld_SpawnParams
{
}

namespace UMars_SmCondition_JumpHeld
{
    FMars_SmCondition_JumpHeld_SpawnParams Params()
    {
        return FMars_SmCondition_JumpHeld_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_JumpPressed_SpawnParams
{
}

namespace UMars_SmCondition_JumpPressed
{
    FMars_SmCondition_JumpPressed_SpawnParams Params()
    {
        return FMars_SmCondition_JumpPressed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_JumpReleased_SpawnParams
{
}

namespace UMars_SmCondition_JumpReleased
{
    FMars_SmCondition_JumpReleased_SpawnParams Params()
    {
        return FMars_SmCondition_JumpReleased_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_NoMoveIntent_SpawnParams
{
}

namespace UMars_SmCondition_NoMoveIntent
{
    FMars_SmCondition_NoMoveIntent_SpawnParams Params()
    {
        return FMars_SmCondition_NoMoveIntent_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_SprintHeld_SpawnParams
{
}

namespace UMars_SmCondition_SprintHeld
{
    FMars_SmCondition_SprintHeld_SpawnParams Params()
    {
        return FMars_SmCondition_SprintHeld_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_SprintReleased_SpawnParams
{
}

namespace UMars_SmCondition_SprintReleased
{
    FMars_SmCondition_SprintReleased_SpawnParams Params()
    {
        return FMars_SmCondition_SprintReleased_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Alive_SpawnParams
{
}

namespace UMars_SmState_Alive
{
    FMars_SmState_Alive_SpawnParams Params()
    {
        return FMars_SmState_Alive_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Downed_SpawnParams
{
}

namespace UMars_SmState_Downed
{
    FMars_SmState_Downed_SpawnParams Params()
    {
        return FMars_SmState_Downed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_ExitAndTerminate_SpawnParams
{
}

namespace UMars_SmState_ExitAndTerminate
{
    FMars_SmState_ExitAndTerminate_SpawnParams Params()
    {
        return FMars_SmState_ExitAndTerminate_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Interactable_Disabled_SpawnParams
{
}

namespace UMars_SmState_Interactable_Disabled
{
    FMars_SmState_Interactable_Disabled_SpawnParams Params()
    {
        return FMars_SmState_Interactable_Disabled_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Interactable_Focused_SpawnParams
{
}

namespace UMars_SmState_Interactable_Focused
{
    FMars_SmState_Interactable_Focused_SpawnParams Params()
    {
        return FMars_SmState_Interactable_Focused_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Interactable_Idle_SpawnParams
{
}

namespace UMars_SmState_Interactable_Idle
{
    FMars_SmState_Interactable_Idle_SpawnParams Params()
    {
        return FMars_SmState_Interactable_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Interactable_Interacting_SpawnParams
{
}

namespace UMars_SmState_Interactable_Interacting
{
    FMars_SmState_Interactable_Interacting_SpawnParams Params()
    {
        return FMars_SmState_Interactable_Interacting_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_InteractTarget_Enter_SpawnParams
{
}

namespace UMars_SmState_InteractTarget_Enter
{
    FMars_SmState_InteractTarget_Enter_SpawnParams Params()
    {
        return FMars_SmState_InteractTarget_Enter_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Lever_Pull_SpawnParams
{
}

namespace UMars_SmState_Lever_Pull
{
    FMars_SmState_Lever_Pull_SpawnParams Params()
    {
        return FMars_SmState_Lever_Pull_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Loco_Airborne_SpawnParams
{
}

namespace UMars_SmState_Loco_Airborne
{
    FMars_SmState_Loco_Airborne_SpawnParams Params()
    {
        return FMars_SmState_Loco_Airborne_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Loco_Crouch_SpawnParams
{
}

namespace UMars_SmState_Loco_Crouch
{
    FMars_SmState_Loco_Crouch_SpawnParams Params()
    {
        return FMars_SmState_Loco_Crouch_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Loco_Idle_SpawnParams
{
}

namespace UMars_SmState_Loco_Idle
{
    FMars_SmState_Loco_Idle_SpawnParams Params()
    {
        return FMars_SmState_Loco_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Loco_Jump_SpawnParams
{
}

namespace UMars_SmState_Loco_Jump
{
    FMars_SmState_Loco_Jump_SpawnParams Params()
    {
        return FMars_SmState_Loco_Jump_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Loco_Sprint_SpawnParams
{
}

namespace UMars_SmState_Loco_Sprint
{
    FMars_SmState_Loco_Sprint_SpawnParams Params()
    {
        return FMars_SmState_Loco_Sprint_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Loco_Walk_SpawnParams
{
}

namespace UMars_SmState_Loco_Walk
{
    FMars_SmState_Loco_Walk_SpawnParams Params()
    {
        return FMars_SmState_Loco_Walk_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Locomotion_SpawnParams
{
}

namespace UMars_SmState_Locomotion
{
    FMars_SmState_Locomotion_SpawnParams Params()
    {
        return FMars_SmState_Locomotion_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Switch_Press_SpawnParams
{
}

namespace UMars_SmState_Switch_Press
{
    FMars_SmState_Switch_Press_SpawnParams Params()
    {
        return FMars_SmState_Switch_Press_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_TestLamp_Toggle_SpawnParams
{
}

namespace UMars_SmState_TestLamp_Toggle
{
    FMars_SmState_TestLamp_Toggle_SpawnParams Params()
    {
        return FMars_SmState_TestLamp_Toggle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_AliveSubSm_SpawnParams
{
}

namespace UMars_SmTask_AliveSubSm
{
    FMars_SmTask_AliveSubSm_SpawnParams Params()
    {
        return FMars_SmTask_AliveSubSm_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crouch_SpawnParams
{
}

namespace UMars_SmTask_Crouch
{
    FMars_SmTask_Crouch_SpawnParams Params()
    {
        return FMars_SmTask_Crouch_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_IntentToResolver_SpawnParams
{
}

namespace UMars_SmTask_IntentToResolver
{
    FMars_SmTask_IntentToResolver_SpawnParams Params()
    {
        return FMars_SmTask_IntentToResolver_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Interactable_Outline_SpawnParams
{
}

namespace UMars_SmTask_Interactable_Outline
{
    FMars_SmTask_Interactable_Outline_SpawnParams Params()
    {
        return FMars_SmTask_Interactable_Outline_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Interactable_ShowPrompt_SpawnParams
{
}

namespace UMars_SmTask_Interactable_ShowPrompt
{
    FMars_SmTask_Interactable_ShowPrompt_SpawnParams Params()
    {
        return FMars_SmTask_Interactable_ShowPrompt_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_InteractionFocus_SpawnParams
{
}

namespace UMars_SmTask_InteractionFocus
{
    FMars_SmTask_InteractionFocus_SpawnParams Params()
    {
        return FMars_SmTask_InteractionFocus_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_InteractionResolverBinds_SpawnParams
{
}

namespace UMars_SmTask_InteractionResolverBinds
{
    FMars_SmTask_InteractionResolverBinds_SpawnParams Params()
    {
        return FMars_SmTask_InteractionResolverBinds_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Jump_SpawnParams
{
}

namespace UMars_SmTask_Jump
{
    FMars_SmTask_Jump_SpawnParams Params()
    {
        return FMars_SmTask_Jump_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Lever_Pull_SpawnParams
{
}

namespace UMars_SmTask_Lever_Pull
{
    FMars_SmTask_Lever_Pull_SpawnParams Params()
    {
        return FMars_SmTask_Lever_Pull_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_LocomotionSpeed_SpawnParams
{
}

namespace UMars_SmTask_LocomotionSpeed
{
    FMars_SmTask_LocomotionSpeed_SpawnParams Params()
    {
        return FMars_SmTask_LocomotionSpeed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_LocomotionSpeed_Sprint_SpawnParams
{
}

namespace UMars_SmTask_LocomotionSpeed_Sprint
{
    FMars_SmTask_LocomotionSpeed_Sprint_SpawnParams Params()
    {
        return FMars_SmTask_LocomotionSpeed_Sprint_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_LocomotionSpeed_Walk_SpawnParams
{
}

namespace UMars_SmTask_LocomotionSpeed_Walk
{
    FMars_SmTask_LocomotionSpeed_Walk_SpawnParams Params()
    {
        return FMars_SmTask_LocomotionSpeed_Walk_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_LocomotionSubSm_SpawnParams
{
}

namespace UMars_SmTask_LocomotionSubSm
{
    FMars_SmTask_LocomotionSubSm_SpawnParams Params()
    {
        return FMars_SmTask_LocomotionSubSm_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Movement_SpawnParams
{
}

namespace UMars_SmTask_Movement
{
    FMars_SmTask_Movement_SpawnParams Params()
    {
        return FMars_SmTask_Movement_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_PerformInteractionSubSm_SpawnParams
{
}

namespace UMars_SmTask_PerformInteractionSubSm
{
    FMars_SmTask_PerformInteractionSubSm_SpawnParams Params()
    {
        return FMars_SmTask_PerformInteractionSubSm_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Switch_Press_SpawnParams
{
}

namespace UMars_SmTask_Switch_Press
{
    FMars_SmTask_Switch_Press_SpawnParams Params()
    {
        return FMars_SmTask_Switch_Press_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_TerminateOwningSm_SpawnParams
{
}

namespace UMars_SmTask_TerminateOwningSm
{
    FMars_SmTask_TerminateOwningSm_SpawnParams Params()
    {
        return FMars_SmTask_TerminateOwningSm_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_TestLamp_Toggle_SpawnParams
{
}

namespace UMars_SmTask_TestLamp_Toggle
{
    FMars_SmTask_TestLamp_Toggle_SpawnParams Params()
    {
        return FMars_SmTask_TestLamp_Toggle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_UseIntentToResolver_SpawnParams
{
}

namespace UMars_SmTask_UseIntentToResolver
{
    FMars_SmTask_UseIntentToResolver_SpawnParams Params()
    {
        return FMars_SmTask_UseIntentToResolver_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_ViewpointSync_SpawnParams
{
}

namespace UMars_SmTask_ViewpointSync
{
    FMars_SmTask_ViewpointSync_SpawnParams Params()
    {
        return FMars_SmTask_ViewpointSync_SpawnParams();
    }
}

USTRUCT()
struct FMars_Switch_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Switch_Spec Switch = FMars_Switch_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    FText PromptText = FText::FromString("Press switch");

    FMars_Switch_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Switch_Spec InSwitch, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Switch = InSwitch;
        Source = InSource;
        PromptText = InPromptText;
    }
}

namespace UMars_Switch_EntityScript
{
    FMars_Switch_EntityScript_SpawnParams Params()
    {
        return FMars_Switch_EntityScript_SpawnParams();
    }

    FMars_Switch_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Switch_Spec InSwitch, FMars_MechanismSource_Spec InSource, FText InPromptText)
    {
        return FMars_Switch_EntityScript_SpawnParams(InSpawnTransform, InSwitch, InSource, InPromptText);
    }
}

USTRUCT()
struct FMars_TestLamp_EntityScript_SpawnParams
{
    UPROPERTY()
    const TWeakObjectPtr<AActor> _OwningActor = nullptr;

    FMars_TestLamp_EntityScript_SpawnParams(const TObjectPtr<AActor> In_OwningActor)
    {
        _OwningActor = TWeakObjectPtr<AActor>(In_OwningActor);
    }
}

namespace UMars_TestLamp_EntityScript
{
    FMars_TestLamp_EntityScript_SpawnParams Params()
    {
        return FMars_TestLamp_EntityScript_SpawnParams();
    }

    FMars_TestLamp_EntityScript_SpawnParams Params(const TObjectPtr<AActor> In_OwningActor)
    {
        return FMars_TestLamp_EntityScript_SpawnParams(In_OwningActor);
    }
}

