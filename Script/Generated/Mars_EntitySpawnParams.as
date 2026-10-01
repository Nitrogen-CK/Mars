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
struct FMars_AutoTest_ActionHintDisplay_RegisterUnregisterByOwner_SpawnParams
{
}

namespace UMars_AutoTest_ActionHintDisplay_RegisterUnregisterByOwner
{
    FMars_AutoTest_ActionHintDisplay_RegisterUnregisterByOwner_SpawnParams Params()
    {
        return FMars_AutoTest_ActionHintDisplay_RegisterUnregisterByOwner_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_ActionHintDisplay_SuppressIsRefCounted_SpawnParams
{
}

namespace UMars_AutoTest_ActionHintDisplay_SuppressIsRefCounted
{
    FMars_AutoTest_ActionHintDisplay_SuppressIsRefCounted_SpawnParams Params()
    {
        return FMars_AutoTest_ActionHintDisplay_SuppressIsRefCounted_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_ActionHintDisplay_UnregisterDestroysRow_SpawnParams
{
}

namespace UMars_AutoTest_ActionHintDisplay_UnregisterDestroysRow
{
    FMars_AutoTest_ActionHintDisplay_UnregisterDestroysRow_SpawnParams Params()
    {
        return FMars_AutoTest_ActionHintDisplay_UnregisterDestroysRow_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_ActionHintDisplay_UpdateBroadcastsOnlyOnChange_SpawnParams
{
}

namespace UMars_AutoTest_ActionHintDisplay_UpdateBroadcastsOnlyOnChange
{
    FMars_AutoTest_ActionHintDisplay_UpdateBroadcastsOnlyOnChange_SpawnParams Params()
    {
        return FMars_AutoTest_ActionHintDisplay_UpdateBroadcastsOnlyOnChange_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_AttachPoints_LookupByTag_SpawnParams
{
}

namespace UMars_AutoTest_AttachPoints_LookupByTag
{
    FMars_AutoTest_AttachPoints_LookupByTag_SpawnParams Params()
    {
        return FMars_AutoTest_AttachPoints_LookupByTag_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Backpack_CargoRejectsBackpack_SpawnParams
{
}

namespace UMars_AutoTest_Backpack_CargoRejectsBackpack
{
    FMars_AutoTest_Backpack_CargoRejectsBackpack_SpawnParams Params()
    {
        return FMars_AutoTest_Backpack_CargoRejectsBackpack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Backpack_CargoStowThenTake_SpawnParams
{
}

namespace UMars_AutoTest_Backpack_CargoStowThenTake
{
    FMars_AutoTest_Backpack_CargoStowThenTake_SpawnParams Params()
    {
        return FMars_AutoTest_Backpack_CargoStowThenTake_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CampSession_PlayBroadcastsOnceLobbyToLive_SpawnParams
{
}

namespace UMars_AutoTest_CampSession_PlayBroadcastsOnceLobbyToLive
{
    FMars_AutoTest_CampSession_PlayBroadcastsOnceLobbyToLive_SpawnParams Params()
    {
        return FMars_AutoTest_CampSession_PlayBroadcastsOnceLobbyToLive_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CampSession_PlayTransitionsToLive_SpawnParams
{
}

namespace UMars_AutoTest_CampSession_PlayTransitionsToLive
{
    FMars_AutoTest_CampSession_PlayTransitionsToLive_SpawnParams Params()
    {
        return FMars_AutoTest_CampSession_PlayTransitionsToLive_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CampSession_PlayWhileLiveIsIgnored_SpawnParams
{
}

namespace UMars_AutoTest_CampSession_PlayWhileLiveIsIgnored
{
    FMars_AutoTest_CampSession_PlayWhileLiveIsIgnored_SpawnParams Params()
    {
        return FMars_AutoTest_CampSession_PlayWhileLiveIsIgnored_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CampSession_StartLiveSpecIsLive_SpawnParams
{
}

namespace UMars_AutoTest_CampSession_StartLiveSpecIsLive
{
    FMars_AutoTest_CampSession_StartLiveSpecIsLive_SpawnParams Params()
    {
        return FMars_AutoTest_CampSession_StartLiveSpecIsLive_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_BackpackSlotTakesOnlyBackpacks_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_BackpackSlotTakesOnlyBackpacks
{
    FMars_AutoTest_Hotbar_BackpackSlotTakesOnlyBackpacks_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_BackpackSlotTakesOnlyBackpacks_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection
{
    FMars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_LeavingOverflowParksSelection_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_LeavingOverflowParksSelection
{
    FMars_AutoTest_Hotbar_LeavingOverflowParksSelection_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_LeavingOverflowParksSelection_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_SelectTogglesAndCycleSkipsOverflow_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_SelectTogglesAndCycleSkipsOverflow
{
    FMars_AutoTest_Hotbar_SelectTogglesAndCycleSkipsOverflow_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_SelectTogglesAndCycleSkipsOverflow_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_SlotItemChangedBroadcasts_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_SlotItemChangedBroadcasts
{
    FMars_AutoTest_Hotbar_SlotItemChangedBroadcasts_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_SlotItemChangedBroadcasts_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_StowFillsBagThenOverflow_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_StowFillsBagThenOverflow
{
    FMars_AutoTest_Hotbar_StowFillsBagThenOverflow_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_StowFillsBagThenOverflow_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_StowTargetIsNoneWhenFull_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_StowTargetIsNoneWhenFull
{
    FMars_AutoTest_Hotbar_StowTargetIsNoneWhenFull_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_StowTargetIsNoneWhenFull_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot
{
    FMars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Smoke_Boots_SpawnParams
{
}

namespace UMars_AutoTest_Smoke_Boots
{
    FMars_AutoTest_Smoke_Boots_SpawnParams Params()
    {
        return FMars_AutoTest_Smoke_Boots_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_ArrivalSettlesAtOffset_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_ArrivalSettlesAtOffset
{
    FMars_AutoTest_WorldItem_ArrivalSettlesAtOffset_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_ArrivalSettlesAtOffset_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_PersistentCarryHoldRelease_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_PersistentCarryHoldRelease
{
    FMars_AutoTest_WorldItem_PersistentCarryHoldRelease_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_PersistentCarryHoldRelease_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_PickupStows_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_PickupStows
{
    FMars_AutoTest_WorldItem_PickupStows_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_PickupStows_SpawnParams();
    }
}

USTRUCT()
struct FMars_Backpack_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition = nullptr;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FCk_Handle AttachTo = FCk_Handle();

    UPROPERTY()
    FTransform AttachOffset = FTransform::Identity;

    UPROPERTY()
    FCk_Handle_Item SourceItem = FCk_Handle_Item();

    UPROPERTY()
    FCk_Handle_Inventory SourceInventory = FCk_Handle_Inventory();

    UPROPERTY()
    FVector LaunchVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    UPROPERTY()
    FMars_WorldItem_Arrival ArriveFrom = FMars_WorldItem_Arrival();

    FMars_Backpack_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        SpawnTransform = InSpawnTransform;
        Definition = InDefinition;
        Mode = InMode;
        AttachTo = InAttachTo;
        AttachOffset = InAttachOffset;
        SourceItem = InSourceItem;
        SourceInventory = InSourceInventory;
        LaunchVelocity = InLaunchVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
        ArriveFrom = InArriveFrom;
    }
}

namespace UMars_Backpack_EntityScript
{
    FMars_Backpack_EntityScript_SpawnParams Params()
    {
        return FMars_Backpack_EntityScript_SpawnParams();
    }

    FMars_Backpack_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Backpack_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
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
struct FMars_HandWheel_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(EMars_Control_Interaction::Timed, 2.0f, EMars_Control_Behavior::Toggle, 1.0f, false);

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    float32 TurnDegrees = 720.0f;

    UPROPERTY()
    float32 MoveDuration = 1.2000000476837158f;

    UPROPERTY()
    FText PromptText = FText::FromString("Turn wheel");

    FMars_HandWheel_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        TurnDegrees = InTurnDegrees;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_HandWheel_EntityScript
{
    FMars_HandWheel_EntityScript_SpawnParams Params()
    {
        return FMars_HandWheel_EntityScript_SpawnParams();
    }

    FMars_HandWheel_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_HandWheel_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InTurnDegrees, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Lever_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.3499999940395355f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull lever");

    FMars_Lever_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PulledAngle = InPulledAngle;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Lever_EntityScript
{
    FMars_Lever_EntityScript_SpawnParams Params()
    {
        return FMars_Lever_EntityScript_SpawnParams();
    }

    FMars_Lever_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Lever_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPulledAngle, InMoveDuration, InPromptText);
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
struct FMars_Pendulum_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Oscillator_Spec Oscillator = FMars_Oscillator_Spec();

    UPROPERTY()
    FMars_Hazard_Spec Hazard = FMars_Hazard_Spec();

    UPROPERTY()
    FMars_Pendulum_Spec Pendulum = FMars_Pendulum_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    float32 ArmLength = 250.0f;

    FMars_Pendulum_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Oscillator_Spec InOscillator, FMars_Hazard_Spec InHazard, FMars_Pendulum_Spec InPendulum, FMars_MechanismSink_Spec InSink, float32 InArmLength)
    {
        SpawnTransform = InSpawnTransform;
        Oscillator = InOscillator;
        Hazard = InHazard;
        Pendulum = InPendulum;
        Sink = InSink;
        ArmLength = InArmLength;
    }
}

namespace UMars_Pendulum_EntityScript
{
    FMars_Pendulum_EntityScript_SpawnParams Params()
    {
        return FMars_Pendulum_EntityScript_SpawnParams();
    }

    FMars_Pendulum_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Oscillator_Spec InOscillator, FMars_Hazard_Spec InHazard, FMars_Pendulum_Spec InPendulum, FMars_MechanismSink_Spec InSink, float32 InArmLength)
    {
        return FMars_Pendulum_EntityScript_SpawnParams(InSpawnTransform, InOscillator, InHazard, InPendulum, InSink, InArmLength);
    }
}

USTRUCT()
struct FMars_PressurePlate_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trigger_Spec Trigger;

    UPROPERTY()
    FMars_Occupancy_Spec Occupancy = FMars_Occupancy_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    FVector PlateSize = FVector(120.0, 120.0, 8.0);

    FMars_PressurePlate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
    }
}

namespace UMars_PressurePlate_EntityScript
{
    FMars_PressurePlate_EntityScript_SpawnParams Params()
    {
        return FMars_PressurePlate_EntityScript_SpawnParams();
    }

    FMars_PressurePlate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize)
    {
        return FMars_PressurePlate_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize);
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
struct FMars_Sandbox_GateF_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate = FMars_Gate_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_Sandbox_GateF_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Sandbox_GateF_EntityScript
{
    FMars_Sandbox_GateF_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateF_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateF_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Sandbox_GateF_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Sandbox_GateI_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate = FMars_Gate_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_Sandbox_GateI_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Sandbox_GateI_EntityScript
{
    FMars_Sandbox_GateI_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateI_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateI_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Sandbox_GateI_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Sandbox_LeverA_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.3499999940395355f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull lever");

    FMars_Sandbox_LeverA_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PulledAngle = InPulledAngle;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_LeverA_EntityScript
{
    FMars_Sandbox_LeverA_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_LeverA_EntityScript_SpawnParams();
    }

    FMars_Sandbox_LeverA_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Sandbox_LeverA_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPulledAngle, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_LeverB_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.3499999940395355f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull lever");

    FMars_Sandbox_LeverB_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PulledAngle = InPulledAngle;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_LeverB_EntityScript
{
    FMars_Sandbox_LeverB_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_LeverB_EntityScript_SpawnParams();
    }

    FMars_Sandbox_LeverB_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Sandbox_LeverB_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPulledAngle, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_LeverK_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.3499999940395355f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull lever");

    FMars_Sandbox_LeverK_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PulledAngle = InPulledAngle;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_LeverK_EntityScript
{
    FMars_Sandbox_LeverK_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_LeverK_EntityScript_SpawnParams();
    }

    FMars_Sandbox_LeverK_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Sandbox_LeverK_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPulledAngle, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_Pendulum_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Oscillator_Spec Oscillator = FMars_Oscillator_Spec();

    UPROPERTY()
    FMars_Hazard_Spec Hazard = FMars_Hazard_Spec();

    UPROPERTY()
    FMars_Pendulum_Spec Pendulum = FMars_Pendulum_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    float32 ArmLength = 250.0f;

    FMars_Sandbox_Pendulum_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Oscillator_Spec InOscillator, FMars_Hazard_Spec InHazard, FMars_Pendulum_Spec InPendulum, FMars_MechanismSink_Spec InSink, float32 InArmLength)
    {
        SpawnTransform = InSpawnTransform;
        Oscillator = InOscillator;
        Hazard = InHazard;
        Pendulum = InPendulum;
        Sink = InSink;
        ArmLength = InArmLength;
    }
}

namespace UMars_Sandbox_Pendulum_EntityScript
{
    FMars_Sandbox_Pendulum_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_Pendulum_EntityScript_SpawnParams();
    }

    FMars_Sandbox_Pendulum_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Oscillator_Spec InOscillator, FMars_Hazard_Spec InHazard, FMars_Pendulum_Spec InPendulum, FMars_MechanismSink_Spec InSink, float32 InArmLength)
    {
        return FMars_Sandbox_Pendulum_EntityScript_SpawnParams(InSpawnTransform, InOscillator, InHazard, InPendulum, InSink, InArmLength);
    }
}

USTRUCT()
struct FMars_Sandbox_PlateF_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trigger_Spec Trigger;

    UPROPERTY()
    FMars_Occupancy_Spec Occupancy = FMars_Occupancy_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FVector PlateSize = FVector(120.0, 120.0, 8.0);

    FMars_Sandbox_PlateF_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
    }
}

namespace UMars_Sandbox_PlateF_EntityScript
{
    FMars_Sandbox_PlateF_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_PlateF_EntityScript_SpawnParams();
    }

    FMars_Sandbox_PlateF_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize)
    {
        return FMars_Sandbox_PlateF_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize);
    }
}

USTRUCT()
struct FMars_Sandbox_SealG_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(EMars_Control_Interaction::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false);

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(0.10000000149011612f, 0.3499999940395355f, 1.0f, 1.0f);

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Sandbox_SealG_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_SealG_EntityScript
{
    FMars_Sandbox_SealG_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SealG_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SealG_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, FText InPromptText)
    {
        return FMars_Sandbox_SealG_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_SealH_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(EMars_Control_Interaction::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false);

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(1.0f, 0.44999998807907104f, 0.05000000074505806f, 1.0f);

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Sandbox_SealH_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_SealH_EntityScript
{
    FMars_Sandbox_SealH_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SealH_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SealH_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, FText InPromptText)
    {
        return FMars_Sandbox_SealH_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_SequenceI_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Sequence_Spec Sequence;

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    FMars_Sandbox_SequenceI_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Sequence = InSequence;
        Source = InSource;
    }
}

namespace UMars_Sandbox_SequenceI_EntityScript
{
    FMars_Sandbox_SequenceI_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SequenceI_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SequenceI_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Sandbox_SequenceI_EntityScript_SpawnParams(InSpawnTransform, InSequence, InSource);
    }
}

USTRUCT()
struct FMars_Sandbox_SpikesK_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trap_Spec Trap;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_Hazard_Spec Hazard = FMars_Hazard_Spec();

    UPROPERTY()
    float32 TileSize = 200.0f;

    FMars_Sandbox_SpikesK_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard, float32 InTileSize)
    {
        SpawnTransform = InSpawnTransform;
        Trap = InTrap;
        Sink = InSink;
        Hazard = InHazard;
        TileSize = InTileSize;
    }
}

namespace UMars_Sandbox_SpikesK_EntityScript
{
    FMars_Sandbox_SpikesK_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SpikesK_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SpikesK_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard, float32 InTileSize)
    {
        return FMars_Sandbox_SpikesK_EntityScript_SpawnParams(InSpawnTransform, InTrap, InSink, InHazard, InTileSize);
    }
}

USTRUCT()
struct FMars_Sandbox_SwitchC_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(EMars_Control_Interaction::Instant, 1.5f, EMars_Control_Behavior::Momentary, 1.0f, false);

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FVector PressOffset = FVector(0.0, 0.0, -6.0);

    UPROPERTY()
    float32 MoveDuration = 0.15000000596046448f;

    UPROPERTY()
    FText PromptText = FText::FromString("Press switch");

    FMars_Sandbox_SwitchC_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FVector InPressOffset, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PressOffset = InPressOffset;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_SwitchC_EntityScript
{
    FMars_Sandbox_SwitchC_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SwitchC_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SwitchC_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FVector InPressOffset, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Sandbox_SwitchC_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPressOffset, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_VentJ_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trap_Spec Trap;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_Hazard_Spec Hazard = FMars_Hazard_Spec();

    FMars_Sandbox_VentJ_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard)
    {
        SpawnTransform = InSpawnTransform;
        Trap = InTrap;
        Sink = InSink;
        Hazard = InHazard;
    }
}

namespace UMars_Sandbox_VentJ_EntityScript
{
    FMars_Sandbox_VentJ_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_VentJ_EntityScript_SpawnParams();
    }

    FMars_Sandbox_VentJ_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard)
    {
        return FMars_Sandbox_VentJ_EntityScript_SpawnParams(InSpawnTransform, InTrap, InSink, InHazard);
    }
}

USTRUCT()
struct FMars_Sandbox_WheelJ_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(EMars_Control_Interaction::Timed, 2.0f, EMars_Control_Behavior::Toggle, 1.0f, false);

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 TurnDegrees = 720.0f;

    UPROPERTY()
    float32 MoveDuration = 1.2000000476837158f;

    UPROPERTY()
    FText PromptText = FText::FromString("Turn wheel");

    FMars_Sandbox_WheelJ_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        TurnDegrees = InTurnDegrees;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_WheelJ_EntityScript
{
    FMars_Sandbox_WheelJ_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_WheelJ_EntityScript_SpawnParams();
    }

    FMars_Sandbox_WheelJ_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Sandbox_WheelJ_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InTurnDegrees, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Seal_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(EMars_Control_Interaction::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false);

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(0.20000000298023224f, 0.800000011920929f, 1.0f, 1.0f);

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Seal_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        PromptText = InPromptText;
    }
}

namespace UMars_Seal_EntityScript
{
    FMars_Seal_EntityScript_SpawnParams Params()
    {
        return FMars_Seal_EntityScript_SpawnParams();
    }

    FMars_Seal_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, FText InPromptText)
    {
        return FMars_Seal_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InPromptText);
    }
}

USTRUCT()
struct FMars_SequenceNode_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Sequence_Spec Sequence;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_SequenceNode_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Sequence = InSequence;
        Source = InSource;
    }
}

namespace UMars_SequenceNode_EntityScript
{
    FMars_SequenceNode_EntityScript_SpawnParams Params()
    {
        return FMars_SequenceNode_EntityScript_SpawnParams();
    }

    FMars_SequenceNode_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        return FMars_SequenceNode_EntityScript_SpawnParams(InSpawnTransform, InSequence, InSource);
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
struct FMars_SmState_Camp_Live_SpawnParams
{
}

namespace UMars_SmState_Camp_Live
{
    FMars_SmState_Camp_Live_SpawnParams Params()
    {
        return FMars_SmState_Camp_Live_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Camp_Lobby_SpawnParams
{
}

namespace UMars_SmState_Camp_Lobby
{
    FMars_SmState_Camp_Lobby_SpawnParams Params()
    {
        return FMars_SmState_Camp_Lobby_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_CargoSlot_Interact_SpawnParams
{
}

namespace UMars_SmState_CargoSlot_Interact
{
    FMars_SmState_CargoSlot_Interact_SpawnParams Params()
    {
        return FMars_SmState_CargoSlot_Interact_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Control_Engage_SpawnParams
{
}

namespace UMars_SmState_Control_Engage
{
    FMars_SmState_Control_Engage_SpawnParams Params()
    {
        return FMars_SmState_Control_Engage_SpawnParams();
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
struct FMars_SmState_ItemUse_Consume_SpawnParams
{
}

namespace UMars_SmState_ItemUse_Consume
{
    FMars_SmState_ItemUse_Consume_SpawnParams Params()
    {
        return FMars_SmState_ItemUse_Consume_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_ItemUse_Throw_SpawnParams
{
}

namespace UMars_SmState_ItemUse_Throw
{
    FMars_SmState_ItemUse_Throw_SpawnParams Params()
    {
        return FMars_SmState_ItemUse_Throw_SpawnParams();
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
struct FMars_SmState_WorldItem_PickUp_SpawnParams
{
}

namespace UMars_SmState_WorldItem_PickUp
{
    FMars_SmState_WorldItem_PickUp_SpawnParams Params()
    {
        return FMars_SmState_WorldItem_PickUp_SpawnParams();
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
struct FMars_SmTask_CargoSlot_StowOrTake_SpawnParams
{
}

namespace UMars_SmTask_CargoSlot_StowOrTake
{
    FMars_SmTask_CargoSlot_StowOrTake_SpawnParams Params()
    {
        return FMars_SmTask_CargoSlot_StowOrTake_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Control_Engage_SpawnParams
{
}

namespace UMars_SmTask_Control_Engage
{
    FMars_SmTask_Control_Engage_SpawnParams Params()
    {
        return FMars_SmTask_Control_Engage_SpawnParams();
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
struct FMars_SmTask_DropThrowIntent_SpawnParams
{
}

namespace UMars_SmTask_DropThrowIntent
{
    FMars_SmTask_DropThrowIntent_SpawnParams Params()
    {
        return FMars_SmTask_DropThrowIntent_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_EmoteIntents_SpawnParams
{
}

namespace UMars_SmTask_EmoteIntents
{
    FMars_SmTask_EmoteIntents_SpawnParams Params()
    {
        return FMars_SmTask_EmoteIntents_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HeldItemDrivesUse_SpawnParams
{
}

namespace UMars_SmTask_HeldItemDrivesUse
{
    FMars_SmTask_HeldItemDrivesUse_SpawnParams Params()
    {
        return FMars_SmTask_HeldItemDrivesUse_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HeldItemHints_SpawnParams
{
}

namespace UMars_SmTask_HeldItemHints
{
    FMars_SmTask_HeldItemHints_SpawnParams Params()
    {
        return FMars_SmTask_HeldItemHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HotbarDrivesHeldItem_SpawnParams
{
}

namespace UMars_SmTask_HotbarDrivesHeldItem
{
    FMars_SmTask_HotbarDrivesHeldItem_SpawnParams Params()
    {
        return FMars_SmTask_HotbarDrivesHeldItem_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HotbarIntents_SpawnParams
{
}

namespace UMars_SmTask_HotbarIntents
{
    FMars_SmTask_HotbarIntents_SpawnParams Params()
    {
        return FMars_SmTask_HotbarIntents_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_IntentEdges_SpawnParams
{
}

namespace UMars_SmTask_IntentEdges
{
    FMars_SmTask_IntentEdges_SpawnParams Params()
    {
        return FMars_SmTask_IntentEdges_SpawnParams();
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
struct FMars_SmTask_ItemUse_Consume_SpawnParams
{
}

namespace UMars_SmTask_ItemUse_Consume
{
    FMars_SmTask_ItemUse_Consume_SpawnParams Params()
    {
        return FMars_SmTask_ItemUse_Consume_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_ItemUse_Throw_SpawnParams
{
}

namespace UMars_SmTask_ItemUse_Throw
{
    FMars_SmTask_ItemUse_Throw_SpawnParams Params()
    {
        return FMars_SmTask_ItemUse_Throw_SpawnParams();
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
struct FMars_SmTask_PrimaryIntentToResolver_SpawnParams
{
}

namespace UMars_SmTask_PrimaryIntentToResolver
{
    FMars_SmTask_PrimaryIntentToResolver_SpawnParams Params()
    {
        return FMars_SmTask_PrimaryIntentToResolver_SpawnParams();
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
struct FMars_SmTask_WorldItem_StowIntoInitiator_SpawnParams
{
}

namespace UMars_SmTask_WorldItem_StowIntoInitiator
{
    FMars_SmTask_WorldItem_StowIntoInitiator_SpawnParams Params()
    {
        return FMars_SmTask_WorldItem_StowIntoInitiator_SpawnParams();
    }
}

USTRUCT()
struct FMars_SpikeTrap_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trap_Spec Trap;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_Hazard_Spec Hazard = FMars_Hazard_Spec();

    UPROPERTY()
    float32 TileSize = 200.0f;

    FMars_SpikeTrap_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard, float32 InTileSize)
    {
        SpawnTransform = InSpawnTransform;
        Trap = InTrap;
        Sink = InSink;
        Hazard = InHazard;
        TileSize = InTileSize;
    }
}

namespace UMars_SpikeTrap_EntityScript
{
    FMars_SpikeTrap_EntityScript_SpawnParams Params()
    {
        return FMars_SpikeTrap_EntityScript_SpawnParams();
    }

    FMars_SpikeTrap_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard, float32 InTileSize)
    {
        return FMars_SpikeTrap_EntityScript_SpawnParams(InSpawnTransform, InTrap, InSink, InHazard, InTileSize);
    }
}

USTRUCT()
struct FMars_Switch_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(EMars_Control_Interaction::Instant, 1.5f, EMars_Control_Behavior::Momentary, 1.0f, false);

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    FVector PressOffset = FVector(0.0, 0.0, -6.0);

    UPROPERTY()
    float32 MoveDuration = 0.15000000596046448f;

    UPROPERTY()
    FText PromptText = FText::FromString("Press switch");

    FMars_Switch_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FVector InPressOffset, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PressOffset = InPressOffset;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Switch_EntityScript
{
    FMars_Switch_EntityScript_SpawnParams Params()
    {
        return FMars_Switch_EntityScript_SpawnParams();
    }

    FMars_Switch_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FVector InPressOffset, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Switch_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPressOffset, InMoveDuration, InPromptText);
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

USTRUCT()
struct FMars_Vent_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trap_Spec Trap;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_Hazard_Spec Hazard = FMars_Hazard_Spec();

    FMars_Vent_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard)
    {
        SpawnTransform = InSpawnTransform;
        Trap = InTrap;
        Sink = InSink;
        Hazard = InHazard;
    }
}

namespace UMars_Vent_EntityScript
{
    FMars_Vent_EntityScript_SpawnParams Params()
    {
        return FMars_Vent_EntityScript_SpawnParams();
    }

    FMars_Vent_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trap_Spec InTrap, FMars_MechanismSink_Spec InSink, FMars_Hazard_Spec InHazard)
    {
        return FMars_Vent_EntityScript_SpawnParams(InSpawnTransform, InTrap, InSink, InHazard);
    }
}

USTRUCT()
struct FMars_WorldItem_Backpack_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition = nullptr;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FCk_Handle AttachTo = FCk_Handle();

    UPROPERTY()
    FTransform AttachOffset = FTransform::Identity;

    UPROPERTY()
    FCk_Handle_Item SourceItem = FCk_Handle_Item();

    UPROPERTY()
    FCk_Handle_Inventory SourceInventory = FCk_Handle_Inventory();

    UPROPERTY()
    FVector LaunchVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    UPROPERTY()
    FMars_WorldItem_Arrival ArriveFrom = FMars_WorldItem_Arrival();

    FMars_WorldItem_Backpack_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        SpawnTransform = InSpawnTransform;
        Definition = InDefinition;
        Mode = InMode;
        AttachTo = InAttachTo;
        AttachOffset = InAttachOffset;
        SourceItem = InSourceItem;
        SourceInventory = InSourceInventory;
        LaunchVelocity = InLaunchVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
        ArriveFrom = InArriveFrom;
    }
}

namespace UMars_WorldItem_Backpack_EntityScript
{
    FMars_WorldItem_Backpack_EntityScript_SpawnParams Params()
    {
        return FMars_WorldItem_Backpack_EntityScript_SpawnParams();
    }

    FMars_WorldItem_Backpack_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_WorldItem_Backpack_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_WorldItem_Cog_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition = nullptr;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FCk_Handle AttachTo = FCk_Handle();

    UPROPERTY()
    FTransform AttachOffset = FTransform::Identity;

    UPROPERTY()
    FCk_Handle_Item SourceItem = FCk_Handle_Item();

    UPROPERTY()
    FCk_Handle_Inventory SourceInventory = FCk_Handle_Inventory();

    UPROPERTY()
    FVector LaunchVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    UPROPERTY()
    FMars_WorldItem_Arrival ArriveFrom = FMars_WorldItem_Arrival();

    FMars_WorldItem_Cog_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        SpawnTransform = InSpawnTransform;
        Definition = InDefinition;
        Mode = InMode;
        AttachTo = InAttachTo;
        AttachOffset = InAttachOffset;
        SourceItem = InSourceItem;
        SourceInventory = InSourceInventory;
        LaunchVelocity = InLaunchVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
        ArriveFrom = InArriveFrom;
    }
}

namespace UMars_WorldItem_Cog_EntityScript
{
    FMars_WorldItem_Cog_EntityScript_SpawnParams Params()
    {
        return FMars_WorldItem_Cog_EntityScript_SpawnParams();
    }

    FMars_WorldItem_Cog_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_WorldItem_Cog_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_WorldItem_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition = nullptr;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FCk_Handle AttachTo = FCk_Handle();

    UPROPERTY()
    FTransform AttachOffset = FTransform::Identity;

    UPROPERTY()
    FCk_Handle_Item SourceItem = FCk_Handle_Item();

    UPROPERTY()
    FCk_Handle_Inventory SourceInventory = FCk_Handle_Inventory();

    UPROPERTY()
    FVector LaunchVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    UPROPERTY()
    FMars_WorldItem_Arrival ArriveFrom = FMars_WorldItem_Arrival();

    FMars_WorldItem_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        SpawnTransform = InSpawnTransform;
        Definition = InDefinition;
        Mode = InMode;
        AttachTo = InAttachTo;
        AttachOffset = InAttachOffset;
        SourceItem = InSourceItem;
        SourceInventory = InSourceInventory;
        LaunchVelocity = InLaunchVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
        ArriveFrom = InArriveFrom;
    }
}

namespace UMars_WorldItem_EntityScript
{
    FMars_WorldItem_EntityScript_SpawnParams Params()
    {
        return FMars_WorldItem_EntityScript_SpawnParams();
    }

    FMars_WorldItem_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_WorldItem_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_WorldItem_Ration_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition = nullptr;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FCk_Handle AttachTo = FCk_Handle();

    UPROPERTY()
    FTransform AttachOffset = FTransform::Identity;

    UPROPERTY()
    FCk_Handle_Item SourceItem = FCk_Handle_Item();

    UPROPERTY()
    FCk_Handle_Inventory SourceInventory = FCk_Handle_Inventory();

    UPROPERTY()
    FVector LaunchVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    UPROPERTY()
    FMars_WorldItem_Arrival ArriveFrom = FMars_WorldItem_Arrival();

    FMars_WorldItem_Ration_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        SpawnTransform = InSpawnTransform;
        Definition = InDefinition;
        Mode = InMode;
        AttachTo = InAttachTo;
        AttachOffset = InAttachOffset;
        SourceItem = InSourceItem;
        SourceInventory = InSourceInventory;
        LaunchVelocity = InLaunchVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
        ArriveFrom = InArriveFrom;
    }
}

namespace UMars_WorldItem_Ration_EntityScript
{
    FMars_WorldItem_Ration_EntityScript_SpawnParams Params()
    {
        return FMars_WorldItem_Ration_EntityScript_SpawnParams();
    }

    FMars_WorldItem_Ration_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_WorldItem_Ration_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_WorldItem_Rock_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition = nullptr;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FCk_Handle AttachTo = FCk_Handle();

    UPROPERTY()
    FTransform AttachOffset = FTransform::Identity;

    UPROPERTY()
    FCk_Handle_Item SourceItem = FCk_Handle_Item();

    UPROPERTY()
    FCk_Handle_Inventory SourceInventory = FCk_Handle_Inventory();

    UPROPERTY()
    FVector LaunchVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    UPROPERTY()
    FMars_WorldItem_Arrival ArriveFrom = FMars_WorldItem_Arrival();

    FMars_WorldItem_Rock_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        SpawnTransform = InSpawnTransform;
        Definition = InDefinition;
        Mode = InMode;
        AttachTo = InAttachTo;
        AttachOffset = InAttachOffset;
        SourceItem = InSourceItem;
        SourceInventory = InSourceInventory;
        LaunchVelocity = InLaunchVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
        ArriveFrom = InArriveFrom;
    }
}

namespace UMars_WorldItem_Rock_EntityScript
{
    FMars_WorldItem_Rock_EntityScript_SpawnParams Params()
    {
        return FMars_WorldItem_Rock_EntityScript_SpawnParams();
    }

    FMars_WorldItem_Rock_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_WorldItem_Rock_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

