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
struct FMars_AutoTest_BodyPart_CrushRuinsAndSeverPreservesCondition_SpawnParams
{
}

namespace UMars_AutoTest_BodyPart_CrushRuinsAndSeverPreservesCondition
{
    FMars_AutoTest_BodyPart_CrushRuinsAndSeverPreservesCondition_SpawnParams Params()
    {
        return FMars_AutoTest_BodyPart_CrushRuinsAndSeverPreservesCondition_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_BodyPart_DepletionSeversLegAndRagdollsParts_SpawnParams
{
}

namespace UMars_AutoTest_BodyPart_DepletionSeversLegAndRagdollsParts
{
    FMars_AutoTest_BodyPart_DepletionSeversLegAndRagdollsParts_SpawnParams Params()
    {
        return FMars_AutoTest_BodyPart_DepletionSeversLegAndRagdollsParts_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_BodyPart_SpillDamagesBody_SpawnParams
{
}

namespace UMars_AutoTest_BodyPart_SpillDamagesBody
{
    FMars_AutoTest_BodyPart_SpillDamagesBody_SpawnParams Params()
    {
        return FMars_AutoTest_BodyPart_SpillDamagesBody_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Brain_FactsDriveLeaf_SpawnParams
{
}

namespace UMars_AutoTest_Brain_FactsDriveLeaf
{
    FMars_AutoTest_Brain_FactsDriveLeaf_SpawnParams Params()
    {
        return FMars_AutoTest_Brain_FactsDriveLeaf_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Brain_LeafConditionDrivesStateMachine_SpawnParams
{
}

namespace UMars_AutoTest_Brain_LeafConditionDrivesStateMachine
{
    FMars_AutoTest_Brain_LeafConditionDrivesStateMachine_SpawnParams Params()
    {
        return FMars_AutoTest_Brain_LeafConditionDrivesStateMachine_SpawnParams();
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
struct FMars_AutoTest_Climber_LocomotionExitDismounts_SpawnParams
{
}

namespace UMars_AutoTest_Climber_LocomotionExitDismounts
{
    FMars_AutoTest_Climber_LocomotionExitDismounts_SpawnParams Params()
    {
        return FMars_AutoTest_Climber_LocomotionExitDismounts_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Climber_MountClimbsAndTopsOut_SpawnParams
{
}

namespace UMars_AutoTest_Climber_MountClimbsAndTopsOut
{
    FMars_AutoTest_Climber_MountClimbsAndTopsOut_SpawnParams Params()
    {
        return FMars_AutoTest_Climber_MountClimbsAndTopsOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Climber_TopMountNeedsDescentBeforeTopOut_SpawnParams
{
}

namespace UMars_AutoTest_Climber_TopMountNeedsDescentBeforeTopOut
{
    FMars_AutoTest_Climber_TopMountNeedsDescentBeforeTopOut_SpawnParams Params()
    {
        return FMars_AutoTest_Climber_TopMountNeedsDescentBeforeTopOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold_SpawnParams
{
}

namespace UMars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold
{
    FMars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold_SpawnParams Params()
    {
        return FMars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_ManipulationWaitsForTheGrip_SpawnParams
{
}

namespace UMars_AutoTest_Control_ManipulationWaitsForTheGrip
{
    FMars_AutoTest_Control_ManipulationWaitsForTheGrip_SpawnParams Params()
    {
        return FMars_AutoTest_Control_ManipulationWaitsForTheGrip_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_PendingGripFreezesCamera_SpawnParams
{
}

namespace UMars_AutoTest_Control_PendingGripFreezesCamera
{
    FMars_AutoTest_Control_PendingGripFreezesCamera_SpawnParams Params()
    {
        return FMars_AutoTest_Control_PendingGripFreezesCamera_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_PullDegreesFollowTheScreenTangent_SpawnParams
{
}

namespace UMars_AutoTest_Control_PullDegreesFollowTheScreenTangent
{
    FMars_AutoTest_Control_PullDegreesFollowTheScreenTangent_SpawnParams Params()
    {
        return FMars_AutoTest_Control_PullDegreesFollowTheScreenTangent_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff_SpawnParams
{
}

namespace UMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff
{
    FMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff_SpawnParams Params()
    {
        return FMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction_SpawnParams
{
}

namespace UMars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction
{
    FMars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction_SpawnParams Params()
    {
        return FMars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack_SpawnParams
{
}

namespace UMars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack
{
    FMars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack_SpawnParams Params()
    {
        return FMars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_ReturnsToRestPullSpringsBackAndPullsAgain_SpawnParams
{
}

namespace UMars_AutoTest_Control_ReturnsToRestPullSpringsBackAndPullsAgain
{
    FMars_AutoTest_Control_ReturnsToRestPullSpringsBackAndPullsAgain_SpawnParams Params()
    {
        return FMars_AutoTest_Control_ReturnsToRestPullSpringsBackAndPullsAgain_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies_SpawnParams
{
}

namespace UMars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies
{
    FMars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies_SpawnParams Params()
    {
        return FMars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack_SpawnParams
{
}

namespace UMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack
{
    FMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack_SpawnParams Params()
    {
        return FMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Countdown_ChargeDrainsOneStepAtATime_SpawnParams
{
}

namespace UMars_AutoTest_Countdown_ChargeDrainsOneStepAtATime
{
    FMars_AutoTest_Countdown_ChargeDrainsOneStepAtATime_SpawnParams Params()
    {
        return FMars_AutoTest_Countdown_ChargeDrainsOneStepAtATime_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Countdown_HoldWhilePoweredStaysFullThenDrains_SpawnParams
{
}

namespace UMars_AutoTest_Countdown_HoldWhilePoweredStaysFullThenDrains
{
    FMars_AutoTest_Countdown_HoldWhilePoweredStaysFullThenDrains_SpawnParams Params()
    {
        return FMars_AutoTest_Countdown_HoldWhilePoweredStaysFullThenDrains_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Countdown_RechargeWhileDrainingRefills_SpawnParams
{
}

namespace UMars_AutoTest_Countdown_RechargeWhileDrainingRefills
{
    FMars_AutoTest_Countdown_RechargeWhileDrainingRefills_SpawnParams Params()
    {
        return FMars_AutoTest_Countdown_RechargeWhileDrainingRefills_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Countdown_SinkEdgeChargesAndSourceFollows_SpawnParams
{
}

namespace UMars_AutoTest_Countdown_SinkEdgeChargesAndSourceFollows
{
    FMars_AutoTest_Countdown_SinkEdgeChargesAndSourceFollows_SpawnParams Params()
    {
        return FMars_AutoTest_Countdown_SinkEdgeChargesAndSourceFollows_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Countdown_SpecValidateRejectsEmptyOrTimeless_SpawnParams
{
}

namespace UMars_AutoTest_Countdown_SpecValidateRejectsEmptyOrTimeless
{
    FMars_AutoTest_Countdown_SpecValidateRejectsEmptyOrTimeless_SpawnParams Params()
    {
        return FMars_AutoTest_Countdown_SpecValidateRejectsEmptyOrTimeless_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Crawler_ComposesWalkerPartsAndMonster_SpawnParams
{
}

namespace UMars_AutoTest_Crawler_ComposesWalkerPartsAndMonster
{
    FMars_AutoTest_Crawler_ComposesWalkerPartsAndMonster_SpawnParams Params()
    {
        return FMars_AutoTest_Crawler_ComposesWalkerPartsAndMonster_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Crawler_CrippledCowers_SpawnParams
{
}

namespace UMars_AutoTest_Crawler_CrippledCowers
{
    FMars_AutoTest_Crawler_CrippledCowers_SpawnParams Params()
    {
        return FMars_AutoTest_Crawler_CrippledCowers_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Crawler_DamageFlinchesThenResumesRoam_SpawnParams
{
}

namespace UMars_AutoTest_Crawler_DamageFlinchesThenResumesRoam
{
    FMars_AutoTest_Crawler_DamageFlinchesThenResumesRoam_SpawnParams Params()
    {
        return FMars_AutoTest_Crawler_DamageFlinchesThenResumesRoam_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns_SpawnParams
{
}

namespace UMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns
{
    FMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns_SpawnParams Params()
    {
        return FMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Crawler_RoamsWithinBounds_SpawnParams
{
}

namespace UMars_AutoTest_Crawler_RoamsWithinBounds
{
    FMars_AutoTest_Crawler_RoamsWithinBounds_SpawnParams Params()
    {
        return FMars_AutoTest_Crawler_RoamsWithinBounds_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Crawler_StrikeSeversLegEndToEnd_SpawnParams
{
}

namespace UMars_AutoTest_Crawler_StrikeSeversLegEndToEnd
{
    FMars_AutoTest_Crawler_StrikeSeversLegEndToEnd_SpawnParams Params()
    {
        return FMars_AutoTest_Crawler_StrikeSeversLegEndToEnd_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_DamageDealer_FriendlyFireRejected_SpawnParams
{
}

namespace UMars_AutoTest_DamageDealer_FriendlyFireRejected
{
    FMars_AutoTest_DamageDealer_FriendlyFireRejected_SpawnParams Params()
    {
        return FMars_AutoTest_DamageDealer_FriendlyFireRejected_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_DamageDealer_ResolvesHurtboxToZone_SpawnParams
{
}

namespace UMars_AutoTest_DamageDealer_ResolvesHurtboxToZone
{
    FMars_AutoTest_DamageDealer_ResolvesHurtboxToZone_SpawnParams Params()
    {
        return FMars_AutoTest_DamageDealer_ResolvesHurtboxToZone_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_DamageDealer_ShapeTraceFindsSilentHurtbox_SpawnParams
{
}

namespace UMars_AutoTest_DamageDealer_ShapeTraceFindsSilentHurtbox
{
    FMars_AutoTest_DamageDealer_ShapeTraceFindsSilentHurtbox_SpawnParams Params()
    {
        return FMars_AutoTest_DamageDealer_ShapeTraceFindsSilentHurtbox_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Dicing_AlignedChopsAdvanceStateAndMoveBand_SpawnParams
{
}

namespace UMars_AutoTest_Dicing_AlignedChopsAdvanceStateAndMoveBand
{
    FMars_AutoTest_Dicing_AlignedChopsAdvanceStateAndMoveBand_SpawnParams Params()
    {
        return FMars_AutoTest_Dicing_AlignedChopsAdvanceStateAndMoveBand_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Dicing_ChopWhileChoppingIsIgnored_SpawnParams
{
}

namespace UMars_AutoTest_Dicing_ChopWhileChoppingIsIgnored
{
    FMars_AutoTest_Dicing_ChopWhileChoppingIsIgnored_SpawnParams Params()
    {
        return FMars_AutoTest_Dicing_ChopWhileChoppingIsIgnored_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Dicing_OffTargetChopDoesNotAdvance_SpawnParams
{
}

namespace UMars_AutoTest_Dicing_OffTargetChopDoesNotAdvance
{
    FMars_AutoTest_Dicing_OffTargetChopDoesNotAdvance_SpawnParams Params()
    {
        return FMars_AutoTest_Dicing_OffTargetChopDoesNotAdvance_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Dicing_RequestedStateSignalsThenOverProcesses_SpawnParams
{
}

namespace UMars_AutoTest_Dicing_RequestedStateSignalsThenOverProcesses
{
    FMars_AutoTest_Dicing_RequestedStateSignalsThenOverProcesses_SpawnParams Params()
    {
        return FMars_AutoTest_Dicing_RequestedStateSignalsThenOverProcesses_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Dicing_SpecValidateRejectsWholeLeavesRequest_SpawnParams
{
}

namespace UMars_AutoTest_Dicing_SpecValidateRejectsWholeLeavesRequest
{
    FMars_AutoTest_Dicing_SpecValidateRejectsWholeLeavesRequest_SpawnParams Params()
    {
        return FMars_AutoTest_Dicing_SpecValidateRejectsWholeLeavesRequest_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_EmoteWheel_OpenHoverChooseClose_SpawnParams
{
}

namespace UMars_AutoTest_EmoteWheel_OpenHoverChooseClose
{
    FMars_AutoTest_EmoteWheel_OpenHoverChooseClose_SpawnParams Params()
    {
        return FMars_AutoTest_EmoteWheel_OpenHoverChooseClose_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_EmoteWheel_SectorMathAndSpec_SpawnParams
{
}

namespace UMars_AutoTest_EmoteWheel_SectorMathAndSpec
{
    FMars_AutoTest_EmoteWheel_SectorMathAndSpec_SpawnParams Params()
    {
        return FMars_AutoTest_EmoteWheel_SectorMathAndSpec_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_ApplyWritesPlate_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_ApplyWritesPlate
{
    FMars_AutoTest_Eyes_ApplyWritesPlate_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_ApplyWritesPlate_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_BlinkCountsAtFixedInterval_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_BlinkCountsAtFixedInterval
{
    FMars_AutoTest_Eyes_BlinkCountsAtFixedInterval_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_BlinkCountsAtFixedInterval_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_EmoteOverStateLayer_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_EmoteOverStateLayer
{
    FMars_AutoTest_Eyes_EmoteOverStateLayer_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_EmoteOverStateLayer_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_ExpressionOverridesThenExpires_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_ExpressionOverridesThenExpires
{
    FMars_AutoTest_Eyes_ExpressionOverridesThenExpires_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_ExpressionOverridesThenExpires_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_ExpressionSuppressesBlink_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_ExpressionSuppressesBlink
{
    FMars_AutoTest_Eyes_ExpressionSuppressesBlink_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_ExpressionSuppressesBlink_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_LookFollowsGaze_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_LookFollowsGaze
{
    FMars_AutoTest_Eyes_LookFollowsGaze_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_LookFollowsGaze_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_LookMasterResolves_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_LookMasterResolves
{
    FMars_AutoTest_Eyes_LookMasterResolves_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_LookMasterResolves_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_LookMatchesMaterialSlots_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_LookMatchesMaterialSlots
{
    FMars_AutoTest_Eyes_LookMatchesMaterialSlots_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_LookMatchesMaterialSlots_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_OneEyeEmoteKeepsStateOnOtherEye_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_OneEyeEmoteKeepsStateOnOtherEye
{
    FMars_AutoTest_Eyes_OneEyeEmoteKeepsStateOnOtherEye_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_OneEyeEmoteKeepsStateOnOtherEye_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_RejectsBadRequest_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_RejectsBadRequest
{
    FMars_AutoTest_Eyes_RejectsBadRequest_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_RejectsBadRequest_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_RetargetMidFadeKeepsDominantCell_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_RetargetMidFadeKeepsDominantCell
{
    FMars_AutoTest_Eyes_RetargetMidFadeKeepsDominantCell_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_RetargetMidFadeKeepsDominantCell_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_SpecRejectsBadInput_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_SpecRejectsBadInput
{
    FMars_AutoTest_Eyes_SpecRejectsBadInput_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_SpecRejectsBadInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_StateSuppressesBlinkUnderEmote_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_StateSuppressesBlinkUnderEmote
{
    FMars_AutoTest_Eyes_StateSuppressesBlinkUnderEmote_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_StateSuppressesBlinkUnderEmote_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Eyes_WinkKeepsOneEye_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_WinkKeepsOneEye
{
    FMars_AutoTest_Eyes_WinkKeepsOneEye_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_WinkKeepsOneEye_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_EyesDummy_ComposesAndWrites_SpawnParams
{
}

namespace UMars_AutoTest_EyesDummy_ComposesAndWrites
{
    FMars_AutoTest_EyesDummy_ComposesAndWrites_SpawnParams Params()
    {
        return FMars_AutoTest_EyesDummy_ComposesAndWrites_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_CenserSpillsPerHitThenRefills_SpawnParams
{
}

namespace UMars_AutoTest_Forage_CenserSpillsPerHitThenRefills
{
    FMars_AutoTest_Forage_CenserSpillsPerHitThenRefills_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_CenserSpillsPerHitThenRefills_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_DestroyedTearsDownPlainHost_SpawnParams
{
}

namespace UMars_AutoTest_Forage_DestroyedTearsDownPlainHost
{
    FMars_AutoTest_Forage_DestroyedTearsDownPlainHost_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_DestroyedTearsDownPlainHost_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_ExhaustedRegrows_SpawnParams
{
}

namespace UMars_AutoTest_Forage_ExhaustedRegrows
{
    FMars_AutoTest_Forage_ExhaustedRegrows_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_ExhaustedRegrows_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_HuskWorldItemCracksIntoKernel_SpawnParams
{
}

namespace UMars_AutoTest_Forage_HuskWorldItemCracksIntoKernel
{
    FMars_AutoTest_Forage_HuskWorldItemCracksIntoKernel_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_HuskWorldItemCracksIntoKernel_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_ReleasesPerRequestThenExhausts_SpawnParams
{
}

namespace UMars_AutoTest_Forage_ReleasesPerRequestThenExhausts
{
    FMars_AutoTest_Forage_ReleasesPerRequestThenExhausts_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_ReleasesPerRequestThenExhausts_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_SpecValidateRejectsBadSpecs_SpawnParams
{
}

namespace UMars_AutoTest_Forage_SpecValidateRejectsBadSpecs
{
    FMars_AutoTest_Forage_SpecValidateRejectsBadSpecs_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_SpecValidateRejectsBadSpecs_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_VineKnockFromThrownItemReleases_SpawnParams
{
}

namespace UMars_AutoTest_Forage_VineKnockFromThrownItemReleases
{
    FMars_AutoTest_Forage_VineKnockFromThrownItemReleases_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_VineKnockFromThrownItemReleases_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Forage_VineStrikeDepletesThenRegrows_SpawnParams
{
}

namespace UMars_AutoTest_Forage_VineStrikeDepletesThenRegrows
{
    FMars_AutoTest_Forage_VineStrikeDepletesThenRegrows_SpawnParams Params()
    {
        return FMars_AutoTest_Forage_VineStrikeDepletesThenRegrows_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_FocusedInteractableDestroyedClearsLean_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_FocusedInteractableDestroyedClearsLean
{
    FMars_AutoTest_FPHands_FocusedInteractableDestroyedClearsLean_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_FocusedInteractableDestroyedClearsLean_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_GripTableGivesEachHandItsOwnAnchor_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_GripTableGivesEachHandItsOwnAnchor
{
    FMars_AutoTest_FPHands_GripTableGivesEachHandItsOwnAnchor_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_GripTableGivesEachHandItsOwnAnchor_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone
{
    FMars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_PushRunsToNoneFromTheLaunchHold_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_PushRunsToNoneFromTheLaunchHold
{
    FMars_AutoTest_FPHands_PushRunsToNoneFromTheLaunchHold_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_PushRunsToNoneFromTheLaunchHold_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha
{
    FMars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_ReachOverrideExtendsPastMaxReach_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_ReachOverrideExtendsPastMaxReach
{
    FMars_AutoTest_FPHands_ReachOverrideExtendsPastMaxReach_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_ReachOverrideExtendsPastMaxReach_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_ReleaseQueuedWithHoldLetsGo_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_ReleaseQueuedWithHoldLetsGo
{
    FMars_AutoTest_FPHands_ReleaseQueuedWithHoldLetsGo_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_ReleaseQueuedWithHoldLetsGo_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_RestResyncsToLiveTimedInteraction_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_RestResyncsToLiveTimedInteraction
{
    FMars_AutoTest_FPHands_RestResyncsToLiveTimedInteraction_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_RestResyncsToLiveTimedInteraction_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_SocketGripFollowsMovingPart_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_SocketGripFollowsMovingPart
{
    FMars_AutoTest_FPHands_SocketGripFollowsMovingPart_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_SocketGripFollowsMovingPart_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_SubSmExitResetsToNone_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_SubSmExitResetsToNone
{
    FMars_AutoTest_FPHands_SubSmExitResetsToNone_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_SubSmExitResetsToNone_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_TargetLostDuringHoldReleasesFromCurrentAlpha_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_TargetLostDuringHoldReleasesFromCurrentAlpha
{
    FMars_AutoTest_FPHands_TargetLostDuringHoldReleasesFromCurrentAlpha_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_TargetLostDuringHoldReleasesFromCurrentAlpha_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_TimedReachHoldsUntilRelease_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_TimedReachHoldsUntilRelease
{
    FMars_AutoTest_FPHands_TimedReachHoldsUntilRelease_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_TimedReachHoldsUntilRelease_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_UnfocusEasesTheLeanOut_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_UnfocusEasesTheLeanOut
{
    FMars_AutoTest_FPHands_UnfocusEasesTheLeanOut_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_UnfocusEasesTheLeanOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_ViewerFacingGripTakesTheBarFromThePlayersSide_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_ViewerFacingGripTakesTheBarFromThePlayersSide
{
    FMars_AutoTest_FPHands_ViewerFacingGripTakesTheBarFromThePlayersSide_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_ViewerFacingGripTakesTheBarFromThePlayersSide_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gate_ThresholdDefersCloseUntilClear_SpawnParams
{
}

namespace UMars_AutoTest_Gate_ThresholdDefersCloseUntilClear
{
    FMars_AutoTest_Gate_ThresholdDefersCloseUntilClear_SpawnParams Params()
    {
        return FMars_AutoTest_Gate_ThresholdDefersCloseUntilClear_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gate_UnsourcedSinkClosesStartOpenGate_SpawnParams
{
}

namespace UMars_AutoTest_Gate_UnsourcedSinkClosesStartOpenGate
{
    FMars_AutoTest_Gate_UnsourcedSinkClosesStartOpenGate_SpawnParams Params()
    {
        return FMars_AutoTest_Gate_UnsourcedSinkClosesStartOpenGate_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gaze_HysteresisHoldsTarget_SpawnParams
{
}

namespace UMars_AutoTest_Gaze_HysteresisHoldsTarget
{
    FMars_AutoTest_Gaze_HysteresisHoldsTarget_SpawnParams Params()
    {
        return FMars_AutoTest_Gaze_HysteresisHoldsTarget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind_SpawnParams
{
}

namespace UMars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind
{
    FMars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind_SpawnParams Params()
    {
        return FMars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gaze_NeverTargetsOwnOwner_SpawnParams
{
}

namespace UMars_AutoTest_Gaze_NeverTargetsOwnOwner
{
    FMars_AutoTest_Gaze_NeverTargetsOwnOwner_SpawnParams Params()
    {
        return FMars_AutoTest_Gaze_NeverTargetsOwnOwner_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gaze_PicksNearestInCone_SpawnParams
{
}

namespace UMars_AutoTest_Gaze_PicksNearestInCone
{
    FMars_AutoTest_Gaze_PicksNearestInCone_SpawnParams Params()
    {
        return FMars_AutoTest_Gaze_PicksNearestInCone_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gaze_SpecRejectsBadInput_SpawnParams
{
}

namespace UMars_AutoTest_Gaze_SpecRejectsBadInput
{
    FMars_AutoTest_Gaze_SpecRejectsBadInput_SpawnParams Params()
    {
        return FMars_AutoTest_Gaze_SpecRejectsBadInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gaze_TargetDestroyedClears_SpawnParams
{
}

namespace UMars_AutoTest_Gaze_TargetDestroyedClears
{
    FMars_AutoTest_Gaze_TargetDestroyedClears_SpawnParams Params()
    {
        return FMars_AutoTest_Gaze_TargetDestroyedClears_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Gaze_TargetWithoutHeadEnsures_SpawnParams
{
}

namespace UMars_AutoTest_Gaze_TargetWithoutHeadEnsures
{
    FMars_AutoTest_Gaze_TargetWithoutHeadEnsures_SpawnParams Params()
    {
        return FMars_AutoTest_Gaze_TargetWithoutHeadEnsures_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Health_DamageLowersCurrentAndSignals_SpawnParams
{
}

namespace UMars_AutoTest_Health_DamageLowersCurrentAndSignals
{
    FMars_AutoTest_Health_DamageLowersCurrentAndSignals_SpawnParams Params()
    {
        return FMars_AutoTest_Health_DamageLowersCurrentAndSignals_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Health_DepletionLatchesOnceForSameFrameLethalHits_SpawnParams
{
}

namespace UMars_AutoTest_Health_DepletionLatchesOnceForSameFrameLethalHits
{
    FMars_AutoTest_Health_DepletionLatchesOnceForSameFrameLethalHits_SpawnParams Params()
    {
        return FMars_AutoTest_Health_DepletionLatchesOnceForSameFrameLethalHits_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Health_HealRaisesCurrentAndClampsAtMax_SpawnParams
{
}

namespace UMars_AutoTest_Health_HealRaisesCurrentAndClampsAtMax
{
    FMars_AutoTest_Health_HealRaisesCurrentAndClampsAtMax_SpawnParams Params()
    {
        return FMars_AutoTest_Health_HealRaisesCurrentAndClampsAtMax_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate_SpawnParams
{
}

namespace UMars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate
{
    FMars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate_SpawnParams Params()
    {
        return FMars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Health_InvulnerableIgnoresDamage_SpawnParams
{
}

namespace UMars_AutoTest_Health_InvulnerableIgnoresDamage
{
    FMars_AutoTest_Health_InvulnerableIgnoresDamage_SpawnParams Params()
    {
        return FMars_AutoTest_Health_InvulnerableIgnoresDamage_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_HitZone_DisabledZoneIgnoresHits_SpawnParams
{
}

namespace UMars_AutoTest_HitZone_DisabledZoneIgnoresHits
{
    FMars_AutoTest_HitZone_DisabledZoneIgnoresHits_SpawnParams Params()
    {
        return FMars_AutoTest_HitZone_DisabledZoneIgnoresHits_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_HitZone_HitScalesByReactionAndForwardsToHealth_SpawnParams
{
}

namespace UMars_AutoTest_HitZone_HitScalesByReactionAndForwardsToHealth
{
    FMars_AutoTest_HitZone_HitScalesByReactionAndForwardsToHealth_SpawnParams Params()
    {
        return FMars_AutoTest_HitZone_HitScalesByReactionAndForwardsToHealth_SpawnParams();
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
struct FMars_AutoTest_Hotbar_SelectionChangesApplyInArrivalOrder_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_SelectionChangesApplyInArrivalOrder
{
    FMars_AutoTest_Hotbar_SelectionChangesApplyInArrivalOrder_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_SelectionChangesApplyInArrivalOrder_SpawnParams();
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
struct FMars_AutoTest_Implement_FastUpwardLookKicksTheLiftAndItSettles_SpawnParams
{
}

namespace UMars_AutoTest_Implement_FastUpwardLookKicksTheLiftAndItSettles
{
    FMars_AutoTest_Implement_FastUpwardLookKicksTheLiftAndItSettles_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_FastUpwardLookKicksTheLiftAndItSettles_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Implement_LookSteersTheTiltAndItLevelsOut_SpawnParams
{
}

namespace UMars_AutoTest_Implement_LookSteersTheTiltAndItLevelsOut
{
    FMars_AutoTest_Implement_LookSteersTheTiltAndItLevelsOut_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_LookSteersTheTiltAndItLevelsOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Implement_OrbitSwirlsTheNodeWhileDrivenAndEasesOut_SpawnParams
{
}

namespace UMars_AutoTest_Implement_OrbitSwirlsTheNodeWhileDrivenAndEasesOut
{
    FMars_AutoTest_Implement_OrbitSwirlsTheNodeWhileDrivenAndEasesOut_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_OrbitSwirlsTheNodeWhileDrivenAndEasesOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Implement_SpecValidateRejectsBadTilts_SpawnParams
{
}

namespace UMars_AutoTest_Implement_SpecValidateRejectsBadTilts
{
    FMars_AutoTest_Implement_SpecValidateRejectsBadTilts_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_SpecValidateRejectsBadTilts_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_InputIntents_LookDeltaSequenceAdvancesPerDrain_SpawnParams
{
}

namespace UMars_AutoTest_InputIntents_LookDeltaSequenceAdvancesPerDrain
{
    FMars_AutoTest_InputIntents_LookDeltaSequenceAdvancesPerDrain_SpawnParams Params()
    {
        return FMars_AutoTest_InputIntents_LookDeltaSequenceAdvancesPerDrain_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_FocusChangesApplyInArrivalOrder_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_FocusChangesApplyInArrivalOrder
{
    FMars_AutoTest_Interactable_FocusChangesApplyInArrivalOrder_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_FocusChangesApplyInArrivalOrder_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_FreeHandsTargetRejectsAFullHand_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_FreeHandsTargetRejectsAFullHand
{
    FMars_AutoTest_Interactable_FreeHandsTargetRejectsAFullHand_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_FreeHandsTargetRejectsAFullHand_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_FullHandsBlockFocusedPromptAndLetGo_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_FullHandsBlockFocusedPromptAndLetGo
{
    FMars_AutoTest_Interactable_FullHandsBlockFocusedPromptAndLetGo_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_FullHandsBlockFocusedPromptAndLetGo_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Ladder_SpecValidateRejectsBadDimensions_SpawnParams
{
}

namespace UMars_AutoTest_Ladder_SpecValidateRejectsBadDimensions
{
    FMars_AutoTest_Ladder_SpecValidateRejectsBadDimensions_SpawnParams Params()
    {
        return FMars_AutoTest_Ladder_SpecValidateRejectsBadDimensions_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_LanFlow_DirectAddressValidation_SpawnParams
{
}

namespace UMars_AutoTest_LanFlow_DirectAddressValidation
{
    FMars_AutoTest_LanFlow_DirectAddressValidation_SpawnParams Params()
    {
        return FMars_AutoTest_LanFlow_DirectAddressValidation_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals_SpawnParams
{
}

namespace UMars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals
{
    FMars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals_SpawnParams Params()
    {
        return FMars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns_SpawnParams
{
}

namespace UMars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns
{
    FMars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns_SpawnParams Params()
    {
        return FMars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle_SpawnParams
{
}

namespace UMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle
{
    FMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle_SpawnParams Params()
    {
        return FMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Resting_BoxOnAKinematicPlateRestsHopsAndSleeps_SpawnParams
{
}

namespace UMars_AutoTest_Resting_BoxOnAKinematicPlateRestsHopsAndSleeps
{
    FMars_AutoTest_Resting_BoxOnAKinematicPlateRestsHopsAndSleeps_SpawnParams Params()
    {
        return FMars_AutoTest_Resting_BoxOnAKinematicPlateRestsHopsAndSleeps_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Resting_SpecValidateRejectsNoTarget_SpawnParams
{
}

namespace UMars_AutoTest_Resting_SpecValidateRejectsNoTarget
{
    FMars_AutoTest_Resting_SpecValidateRejectsNoTarget_SpawnParams Params()
    {
        return FMars_AutoTest_Resting_SpecValidateRejectsNoTarget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_FastUpwardLookTossesTheSteak_SpawnParams
{
}

namespace UMars_AutoTest_Searing_FastUpwardLookTossesTheSteak
{
    FMars_AutoTest_Searing_FastUpwardLookTossesTheSteak_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_FastUpwardLookTossesTheSteak_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace_SpawnParams
{
}

namespace UMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace
{
    FMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip_SpawnParams
{
}

namespace UMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip
{
    FMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_HeldTiltParksTheSteakAgainstTheLip_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_LookTiltsThePanAndItLevelsOut_SpawnParams
{
}

namespace UMars_AutoTest_Searing_LookTiltsThePanAndItLevelsOut
{
    FMars_AutoTest_Searing_LookTiltsThePanAndItLevelsOut_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_LookTiltsThePanAndItLevelsOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_ResetDestroysTheSteakLevelsThePanAndChills_SpawnParams
{
}

namespace UMars_AutoTest_Searing_ResetDestroysTheSteakLevelsThePanAndChills
{
    FMars_AutoTest_Searing_ResetDestroysTheSteakLevelsThePanAndChills_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_ResetDestroysTheSteakLevelsThePanAndChills_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_SpecValidateRejectsBadPans_SpawnParams
{
}

namespace UMars_AutoTest_Searing_SpecValidateRejectsBadPans
{
    FMars_AutoTest_Searing_SpecValidateRejectsBadPans_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_SpecValidateRejectsBadPans_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndAFreshOneAppears_SpawnParams
{
}

namespace UMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndAFreshOneAppears
{
    FMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndAFreshOneAppears_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndAFreshOneAppears_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_TeleportingEachFaceDownCompletes_SpawnParams
{
}

namespace UMars_AutoTest_Searing_TeleportingEachFaceDownCompletes
{
    FMars_AutoTest_Searing_TeleportingEachFaceDownCompletes_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_TeleportingEachFaceDownCompletes_SpawnParams();
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
struct FMars_AutoTest_Station_GripsResolveToRegisteredNodes_SpawnParams
{
}

namespace UMars_AutoTest_Station_GripsResolveToRegisteredNodes
{
    FMars_AutoTest_Station_GripsResolveToRegisteredNodes_SpawnParams Params()
    {
        return FMars_AutoTest_Station_GripsResolveToRegisteredNodes_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_OperatorDestroyedReleases_SpawnParams
{
}

namespace UMars_AutoTest_Station_OperatorDestroyedReleases
{
    FMars_AutoTest_Station_OperatorDestroyedReleases_SpawnParams Params()
    {
        return FMars_AutoTest_Station_OperatorDestroyedReleases_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_ReserveRejectsSecondOperator_SpawnParams
{
}

namespace UMars_AutoTest_Station_ReserveRejectsSecondOperator
{
    FMars_AutoTest_Station_ReserveRejectsSecondOperator_SpawnParams Params()
    {
        return FMars_AutoTest_Station_ReserveRejectsSecondOperator_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_ReserveWhileOperatingElsewhereRejected_SpawnParams
{
}

namespace UMars_AutoTest_Station_ReserveWhileOperatingElsewhereRejected
{
    FMars_AutoTest_Station_ReserveWhileOperatingElsewhereRejected_SpawnParams Params()
    {
        return FMars_AutoTest_Station_ReserveWhileOperatingElsewhereRejected_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_ScopedReleaseKeepsHolder_SpawnParams
{
}

namespace UMars_AutoTest_Station_ScopedReleaseKeepsHolder
{
    FMars_AutoTest_Station_ScopedReleaseKeepsHolder_SpawnParams Params()
    {
        return FMars_AutoTest_Station_ScopedReleaseKeepsHolder_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall
{
    FMars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceNavigator_SameFrameStopAndMoveToKeepArrivalOrder_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceNavigator_SameFrameStopAndMoveToKeepArrivalOrder
{
    FMars_AutoTest_SurfaceNavigator_SameFrameStopAndMoveToKeepArrivalOrder_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceNavigator_SameFrameStopAndMoveToKeepArrivalOrder_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceNavigator_StopHaltsMovement_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceNavigator_StopHaltsMovement
{
    FMars_AutoTest_SurfaceNavigator_StopHaltsMovement_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceNavigator_StopHaltsMovement_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceNavigator_StraightLineArrives_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceNavigator_StraightLineArrives
{
    FMars_AutoTest_SurfaceNavigator_StraightLineArrives_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceNavigator_StraightLineArrives_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceNavigator_StuckBehindWallFails_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceNavigator_StuckBehindWallFails
{
    FMars_AutoTest_SurfaceNavigator_StuckBehindWallFails_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceNavigator_StuckBehindWallFails_SpawnParams();
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
struct FMars_AutoTestCondition_LeafIsFlinch_SpawnParams
{
}

namespace UMars_AutoTestCondition_LeafIsFlinch
{
    FMars_AutoTestCondition_LeafIsFlinch_SpawnParams Params()
    {
        return FMars_AutoTestCondition_LeafIsFlinch_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestCondition_LeafIsNotFlinch_SpawnParams
{
}

namespace UMars_AutoTestCondition_LeafIsNotFlinch
{
    FMars_AutoTestCondition_LeafIsNotFlinch_SpawnParams Params()
    {
        return FMars_AutoTestCondition_LeafIsNotFlinch_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestCondition_LeafIsNotRoam_SpawnParams
{
}

namespace UMars_AutoTestCondition_LeafIsNotRoam
{
    FMars_AutoTestCondition_LeafIsNotRoam_SpawnParams Params()
    {
        return FMars_AutoTestCondition_LeafIsNotRoam_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestCondition_LeafIsRoam_SpawnParams
{
}

namespace UMars_AutoTestCondition_LeafIsRoam
{
    FMars_AutoTestCondition_LeafIsRoam_SpawnParams Params()
    {
        return FMars_AutoTestCondition_LeafIsRoam_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_BareLocomotion_SpawnParams
{
}

namespace UMars_AutoTestState_BareLocomotion
{
    FMars_AutoTestState_BareLocomotion_SpawnParams Params()
    {
        return FMars_AutoTestState_BareLocomotion_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_BrainFlinch_SpawnParams
{
}

namespace UMars_AutoTestState_BrainFlinch
{
    FMars_AutoTestState_BrainFlinch_SpawnParams Params()
    {
        return FMars_AutoTestState_BrainFlinch_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_BrainIdle_SpawnParams
{
}

namespace UMars_AutoTestState_BrainIdle
{
    FMars_AutoTestState_BrainIdle_SpawnParams Params()
    {
        return FMars_AutoTestState_BrainIdle_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_BrainRoam_SpawnParams
{
}

namespace UMars_AutoTestState_BrainRoam
{
    FMars_AutoTestState_BrainRoam_SpawnParams Params()
    {
        return FMars_AutoTestState_BrainRoam_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_FreeHandsCarrierRig_SpawnParams
{
}

namespace UMars_AutoTestState_FreeHandsCarrierRig
{
    FMars_AutoTestState_FreeHandsCarrierRig_SpawnParams Params()
    {
        return FMars_AutoTestState_FreeHandsCarrierRig_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_FullHandsCarrierRig_SpawnParams
{
}

namespace UMars_AutoTestState_FullHandsCarrierRig
{
    FMars_AutoTestState_FullHandsCarrierRig_SpawnParams Params()
    {
        return FMars_AutoTestState_FullHandsCarrierRig_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_LeftLocomotion_SpawnParams
{
}

namespace UMars_AutoTestState_LeftLocomotion
{
    FMars_AutoTestState_LeftLocomotion_SpawnParams Params()
    {
        return FMars_AutoTestState_LeftLocomotion_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_ManipulateControlRig_SpawnParams
{
}

namespace UMars_AutoTestState_ManipulateControlRig
{
    FMars_AutoTestState_ManipulateControlRig_SpawnParams Params()
    {
        return FMars_AutoTestState_ManipulateControlRig_SpawnParams();
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
struct FMars_CampUiStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    EMars_CampStation Station = EMars_CampStation::Contracts;

    UPROPERTY()
    FVector ProbeDimensions = FVector(15.0, 65.0, 70.0);

    FMars_CampUiStation_EntityScript_SpawnParams(FTransform InSpawnTransform, EMars_CampStation InStation, FVector InProbeDimensions)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        ProbeDimensions = InProbeDimensions;
    }
}

namespace UMars_CampUiStation_EntityScript
{
    FMars_CampUiStation_EntityScript_SpawnParams Params()
    {
        return FMars_CampUiStation_EntityScript_SpawnParams();
    }

    FMars_CampUiStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, EMars_CampStation InStation, FVector InProbeDimensions)
    {
        return FMars_CampUiStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InProbeDimensions);
    }
}

USTRUCT()
struct FMars_Crawler_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Crawler_Spec Spec;

    UPROPERTY()
    FLinearColor Color = FLinearColor(0.75f, 0.3499999940395355f, 0.20000000298023224f, 1.0f);

    UPROPERTY()
    bool WithVisuals = true;

    FMars_Crawler_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals)
    {
        SpawnTransform = InSpawnTransform;
        Spec = InSpec;
        Color = InColor;
        WithVisuals = InWithVisuals;
    }
}

namespace UMars_Crawler_EntityScript
{
    FMars_Crawler_EntityScript_SpawnParams Params()
    {
        return FMars_Crawler_EntityScript_SpawnParams();
    }

    FMars_Crawler_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals)
    {
        return FMars_Crawler_EntityScript_SpawnParams(InSpawnTransform, InSpec, InColor, InWithVisuals);
    }
}

USTRUCT()
struct FMars_DicingStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    UPROPERTY()
    FMars_Dicing_Spec Dicing = FMars_Dicing_Spec();

    FMars_DicingStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_Dicing_Spec InDicing)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        Dicing = InDicing;
    }
}

namespace UMars_DicingStation_EntityScript
{
    FMars_DicingStation_EntityScript_SpawnParams Params()
    {
        return FMars_DicingStation_EntityScript_SpawnParams();
    }

    FMars_DicingStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_Dicing_Spec InDicing)
    {
        return FMars_DicingStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InDicing);
    }
}

USTRUCT()
struct FMars_EyesDummy_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    FMars_EyesDummy_EntityScript_SpawnParams(FTransform InSpawnTransform)
    {
        SpawnTransform = InSpawnTransform;
    }
}

namespace UMars_EyesDummy_EntityScript
{
    FMars_EyesDummy_EntityScript_SpawnParams Params()
    {
        return FMars_EyesDummy_EntityScript_SpawnParams();
    }

    FMars_EyesDummy_EntityScript_SpawnParams Params(FTransform InSpawnTransform)
    {
        return FMars_EyesDummy_EntityScript_SpawnParams(InSpawnTransform);
    }
}

USTRUCT()
struct FMars_Forage_BellnutVine_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 HangHeight = 220.0f;

    UPROPERTY()
    float32 FruitRadius = 22.0f;

    UPROPERTY()
    float32 HitPoints = 1.0f;

    UPROPERTY()
    float32 RegrowSeconds = 30.0f;

    UPROPERTY()
    float32 KnockMinSpeed = 300.0f;

    UPROPERTY()
    bool WithVisuals = true;

    FMars_Forage_BellnutVine_EntityScript_SpawnParams(FTransform InSpawnTransform, float32 InHangHeight, float32 InFruitRadius, float32 InHitPoints, float32 InRegrowSeconds, float32 InKnockMinSpeed, bool InWithVisuals)
    {
        SpawnTransform = InSpawnTransform;
        HangHeight = InHangHeight;
        FruitRadius = InFruitRadius;
        HitPoints = InHitPoints;
        RegrowSeconds = InRegrowSeconds;
        KnockMinSpeed = InKnockMinSpeed;
        WithVisuals = InWithVisuals;
    }
}

namespace UMars_Forage_BellnutVine_EntityScript
{
    FMars_Forage_BellnutVine_EntityScript_SpawnParams Params()
    {
        return FMars_Forage_BellnutVine_EntityScript_SpawnParams();
    }

    FMars_Forage_BellnutVine_EntityScript_SpawnParams Params(FTransform InSpawnTransform, float32 InHangHeight, float32 InFruitRadius, float32 InHitPoints, float32 InRegrowSeconds, float32 InKnockMinSpeed, bool InWithVisuals)
    {
        return FMars_Forage_BellnutVine_EntityScript_SpawnParams(InSpawnTransform, InHangHeight, InFruitRadius, InHitPoints, InRegrowSeconds, InKnockMinSpeed, InWithVisuals);
    }
}

USTRUCT()
struct FMars_Forage_FigVine_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 HangHeight = 220.0f;

    UPROPERTY()
    float32 FruitRadius = 22.0f;

    UPROPERTY()
    float32 HitPoints = 1.0f;

    UPROPERTY()
    float32 RegrowSeconds = 30.0f;

    UPROPERTY()
    float32 KnockMinSpeed = 300.0f;

    UPROPERTY()
    bool WithVisuals = true;

    FMars_Forage_FigVine_EntityScript_SpawnParams(FTransform InSpawnTransform, float32 InHangHeight, float32 InFruitRadius, float32 InHitPoints, float32 InRegrowSeconds, float32 InKnockMinSpeed, bool InWithVisuals)
    {
        SpawnTransform = InSpawnTransform;
        HangHeight = InHangHeight;
        FruitRadius = InFruitRadius;
        HitPoints = InHitPoints;
        RegrowSeconds = InRegrowSeconds;
        KnockMinSpeed = InKnockMinSpeed;
        WithVisuals = InWithVisuals;
    }
}

namespace UMars_Forage_FigVine_EntityScript
{
    FMars_Forage_FigVine_EntityScript_SpawnParams Params()
    {
        return FMars_Forage_FigVine_EntityScript_SpawnParams();
    }

    FMars_Forage_FigVine_EntityScript_SpawnParams Params(FTransform InSpawnTransform, float32 InHangHeight, float32 InFruitRadius, float32 InHitPoints, float32 InRegrowSeconds, float32 InKnockMinSpeed, bool InWithVisuals)
    {
        return FMars_Forage_FigVine_EntityScript_SpawnParams(InSpawnTransform, InHangHeight, InFruitRadius, InHitPoints, InRegrowSeconds, InKnockMinSpeed, InWithVisuals);
    }
}

USTRUCT()
struct FMars_ForageCenser_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 SwingAmplitudeDegrees = 18.0f;

    UPROPERTY()
    float32 SwingPeriodSeconds = 2.200000047683716f;

    UPROPERTY()
    float32 SwingSettleSeconds = 0.800000011920929f;

    UPROPERTY()
    float32 SwingSeconds = 3.0f;

    UPROPERTY()
    float32 ArmLength = 160.0f;

    UPROPERTY()
    int Charges = 3;

    UPROPERTY()
    float32 RefillSeconds = 20.0f;

    UPROPERTY()
    float32 KnockMinSpeed = 500.0f;

    UPROPERTY()
    bool WithVisuals = true;

    FMars_ForageCenser_EntityScript_SpawnParams(FTransform InSpawnTransform, float32 InSwingAmplitudeDegrees, float32 InSwingPeriodSeconds, float32 InSwingSettleSeconds, float32 InSwingSeconds, float32 InArmLength, int InCharges, float32 InRefillSeconds, float32 InKnockMinSpeed, bool InWithVisuals)
    {
        SpawnTransform = InSpawnTransform;
        SwingAmplitudeDegrees = InSwingAmplitudeDegrees;
        SwingPeriodSeconds = InSwingPeriodSeconds;
        SwingSettleSeconds = InSwingSettleSeconds;
        SwingSeconds = InSwingSeconds;
        ArmLength = InArmLength;
        Charges = InCharges;
        RefillSeconds = InRefillSeconds;
        KnockMinSpeed = InKnockMinSpeed;
        WithVisuals = InWithVisuals;
    }
}

namespace UMars_ForageCenser_EntityScript
{
    FMars_ForageCenser_EntityScript_SpawnParams Params()
    {
        return FMars_ForageCenser_EntityScript_SpawnParams();
    }

    FMars_ForageCenser_EntityScript_SpawnParams Params(FTransform InSpawnTransform, float32 InSwingAmplitudeDegrees, float32 InSwingPeriodSeconds, float32 InSwingSettleSeconds, float32 InSwingSeconds, float32 InArmLength, int InCharges, float32 InRefillSeconds, float32 InKnockMinSpeed, bool InWithVisuals)
    {
        return FMars_ForageCenser_EntityScript_SpawnParams(InSpawnTransform, InSwingAmplitudeDegrees, InSwingPeriodSeconds, InSwingSettleSeconds, InSwingSeconds, InArmLength, InCharges, InRefillSeconds, InKnockMinSpeed, InWithVisuals);
    }
}

USTRUCT()
struct FMars_ForageDebris_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh = nullptr;

    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> Material = nullptr;

    UPROPERTY()
    FVector Scale = FVector(0.2, 0.2, 0.1);

    UPROPERTY()
    float32 LifetimeSeconds = 8.0f;

    FMars_ForageDebris_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UStaticMesh> InMesh, TSoftObjectPtr<UMaterialInterface> InMaterial, FVector InScale, float32 InLifetimeSeconds)
    {
        SpawnTransform = InSpawnTransform;
        Mesh = InMesh;
        Material = InMaterial;
        Scale = InScale;
        LifetimeSeconds = InLifetimeSeconds;
    }
}

namespace UMars_ForageDebris_EntityScript
{
    FMars_ForageDebris_EntityScript_SpawnParams Params()
    {
        return FMars_ForageDebris_EntityScript_SpawnParams();
    }

    FMars_ForageDebris_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UStaticMesh> InMesh, TSoftObjectPtr<UMaterialInterface> InMaterial, FVector InScale, float32 InLifetimeSeconds)
    {
        return FMars_ForageDebris_EntityScript_SpawnParams(InSpawnTransform, InMesh, InMaterial, InScale, InLifetimeSeconds);
    }
}

USTRUCT()
struct FMars_Gate_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Gate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gate_EntityScript
{
    FMars_Gate_EntityScript_SpawnParams Params()
    {
        return FMars_Gate_EntityScript_SpawnParams();
    }

    FMars_Gate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gate_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Bell_CircleSeal_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(1.0f, 0.6000000238418579f, 0.15000000596046448f, 1.0f);

    UPROPERTY()
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Circle;

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Gauntlet_Bell_CircleSeal_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        Glyph = InGlyph;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Bell_CircleSeal_EntityScript
{
    FMars_Gauntlet_Bell_CircleSeal_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Bell_CircleSeal_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Bell_CircleSeal_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        return FMars_Gauntlet_Bell_CircleSeal_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InGlyph, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Bell_ReliquaryGate_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Bars;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Gauntlet_Bell_ReliquaryGate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gauntlet_Bell_ReliquaryGate_EntityScript
{
    FMars_Gauntlet_Bell_ReliquaryGate_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Bell_ReliquaryGate_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Bell_ReliquaryGate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gauntlet_Bell_ReliquaryGate_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Bell_ReturnDoor_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Gauntlet_Bell_ReturnDoor_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gauntlet_Bell_ReturnDoor_EntityScript
{
    FMars_Gauntlet_Bell_ReturnDoor_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Bell_ReturnDoor_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Bell_ReturnDoor_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gauntlet_Bell_ReturnDoor_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Bell_ReturnWheel_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Timed, 2.0f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 TurnDegrees = 720.0f;

    UPROPERTY()
    float32 MoveDuration = 1.2000000476837158f;

    UPROPERTY()
    FText PromptText = FText::FromString("Turn wheel");

    FMars_Gauntlet_Bell_ReturnWheel_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        TurnDegrees = InTurnDegrees;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Bell_ReturnWheel_EntityScript
{
    FMars_Gauntlet_Bell_ReturnWheel_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Bell_ReturnWheel_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Bell_ReturnWheel_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Gauntlet_Bell_ReturnWheel_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InTurnDegrees, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Bell_Sequence_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Sequence_Spec Sequence;

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    FMars_Gauntlet_Bell_Sequence_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Sequence = InSequence;
        Source = InSource;
    }
}

namespace UMars_Gauntlet_Bell_Sequence_EntityScript
{
    FMars_Gauntlet_Bell_Sequence_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Bell_Sequence_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Bell_Sequence_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Gauntlet_Bell_Sequence_EntityScript_SpawnParams(InSpawnTransform, InSequence, InSource);
    }
}

USTRUCT()
struct FMars_Gauntlet_Bell_TriangleSeal_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(1.0f, 0.6000000238418579f, 0.15000000596046448f, 1.0f);

    UPROPERTY()
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Triangle;

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Gauntlet_Bell_TriangleSeal_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        Glyph = InGlyph;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Bell_TriangleSeal_EntityScript
{
    FMars_Gauntlet_Bell_TriangleSeal_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Bell_TriangleSeal_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Bell_TriangleSeal_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        return FMars_Gauntlet_Bell_TriangleSeal_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InGlyph, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Censer_Chain_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::ManuallyCompleted, 1.5f, EMars_Control_Behavior::Momentary, 0.25f, false, FMars_Control_Manipulation_Spec(FVector(0.0, 0.0, -1.0), 0.029999999329447746f, 0.8500000238418579f, 60.0f, 12.0f, true));

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PullDistance = 40.0f;

    UPROPERTY()
    float32 ChainLength = 110.0f;

    UPROPERTY()
    float32 MoveDuration = 0.30000001192092896f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull chain");

    FMars_Gauntlet_Censer_Chain_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PullDistance = InPullDistance;
        ChainLength = InChainLength;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Censer_Chain_EntityScript
{
    FMars_Gauntlet_Censer_Chain_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Censer_Chain_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Censer_Chain_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Gauntlet_Censer_Chain_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPullDistance, InChainLength, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Censer_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Oscillator_Spec Oscillator;

    UPROPERTY()
    FMars_Hazard_Spec Hazard = FMars_Hazard_Spec();

    UPROPERTY()
    FMars_Pendulum_Spec Pendulum = FMars_Pendulum_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    float32 ArmLength = 250.0f;

    FMars_Gauntlet_Censer_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Oscillator_Spec InOscillator, FMars_Hazard_Spec InHazard, FMars_Pendulum_Spec InPendulum, FMars_MechanismSink_Spec InSink, float32 InArmLength)
    {
        SpawnTransform = InSpawnTransform;
        Oscillator = InOscillator;
        Hazard = InHazard;
        Pendulum = InPendulum;
        Sink = InSink;
        ArmLength = InArmLength;
    }
}

namespace UMars_Gauntlet_Censer_EntityScript
{
    FMars_Gauntlet_Censer_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Censer_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Censer_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Oscillator_Spec InOscillator, FMars_Hazard_Spec InHazard, FMars_Pendulum_Spec InPendulum, FMars_MechanismSink_Spec InSink, float32 InArmLength)
    {
        return FMars_Gauntlet_Censer_EntityScript_SpawnParams(InSpawnTransform, InOscillator, InHazard, InPendulum, InSink, InArmLength);
    }
}

USTRUCT()
struct FMars_Gauntlet_Censer_Lamps_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Countdown_Spec Countdown = FMars_Countdown_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    FMars_Gauntlet_Censer_Lamps_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Countdown = InCountdown;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Gauntlet_Censer_Lamps_EntityScript
{
    FMars_Gauntlet_Censer_Lamps_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Censer_Lamps_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Censer_Lamps_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Gauntlet_Censer_Lamps_EntityScript_SpawnParams(InSpawnTransform, InCountdown, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Gauntlet_Censer_Shutter_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = true;

    FMars_Gauntlet_Censer_Shutter_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gauntlet_Censer_Shutter_EntityScript
{
    FMars_Gauntlet_Censer_Shutter_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Censer_Shutter_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Censer_Shutter_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gauntlet_Censer_Shutter_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Choir_CircleSeal_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(1.0f, 0.6000000238418579f, 0.15000000596046448f, 1.0f);

    UPROPERTY()
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Circle;

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Gauntlet_Choir_CircleSeal_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        Glyph = InGlyph;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Choir_CircleSeal_EntityScript
{
    FMars_Gauntlet_Choir_CircleSeal_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Choir_CircleSeal_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Choir_CircleSeal_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        return FMars_Gauntlet_Choir_CircleSeal_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InGlyph, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Choir_Sequence_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Sequence_Spec Sequence;

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    FMars_Gauntlet_Choir_Sequence_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Sequence = InSequence;
        Source = InSource;
    }
}

namespace UMars_Gauntlet_Choir_Sequence_EntityScript
{
    FMars_Gauntlet_Choir_Sequence_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Choir_Sequence_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Choir_Sequence_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Sequence_Spec InSequence, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Gauntlet_Choir_Sequence_EntityScript_SpawnParams(InSpawnTransform, InSequence, InSource);
    }
}

USTRUCT()
struct FMars_Gauntlet_Choir_Shutter_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Gauntlet_Choir_Shutter_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gauntlet_Choir_Shutter_EntityScript
{
    FMars_Gauntlet_Choir_Shutter_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Choir_Shutter_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Choir_Shutter_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gauntlet_Choir_Shutter_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Choir_TriangleSeal_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(1.0f, 0.6000000238418579f, 0.15000000596046448f, 1.0f);

    UPROPERTY()
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Triangle;

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Gauntlet_Choir_TriangleSeal_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        Glyph = InGlyph;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Choir_TriangleSeal_EntityScript
{
    FMars_Gauntlet_Choir_TriangleSeal_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Choir_TriangleSeal_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Choir_TriangleSeal_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        return FMars_Gauntlet_Choir_TriangleSeal_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InGlyph, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Choir_VaultGate_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Bars;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Gauntlet_Choir_VaultGate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gauntlet_Choir_VaultGate_EntityScript
{
    FMars_Gauntlet_Choir_VaultGate_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Choir_VaultGate_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Choir_VaultGate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gauntlet_Choir_VaultGate_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Choir_Wheel_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Timed, 2.0f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 TurnDegrees = 720.0f;

    UPROPERTY()
    float32 MoveDuration = 1.2000000476837158f;

    UPROPERTY()
    FText PromptText = FText::FromString("Turn wheel");

    FMars_Gauntlet_Choir_Wheel_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        TurnDegrees = InTurnDegrees;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Choir_Wheel_EntityScript
{
    FMars_Gauntlet_Choir_Wheel_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Choir_Wheel_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Choir_Wheel_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InTurnDegrees, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Gauntlet_Choir_Wheel_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InTurnDegrees, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Fungus_EntityScript_SpawnParams
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

    FMars_Gauntlet_Fungus_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Gauntlet_Fungus_EntityScript
{
    FMars_Gauntlet_Fungus_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Fungus_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Fungus_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Gauntlet_Fungus_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_Gauntlet_Mourner_AlcoveGate_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Bars;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Gauntlet_Mourner_AlcoveGate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gauntlet_Mourner_AlcoveGate_EntityScript
{
    FMars_Gauntlet_Mourner_AlcoveGate_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Mourner_AlcoveGate_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Mourner_AlcoveGate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gauntlet_Mourner_AlcoveGate_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Mourner_ChefPlate_EntityScript_SpawnParams
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

    UPROPERTY()
    TSoftObjectPtr<UTexture2D> DecalTexture = nullptr;

    FMars_Gauntlet_Mourner_ChefPlate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
        DecalTexture = InDecalTexture;
    }
}

namespace UMars_Gauntlet_Mourner_ChefPlate_EntityScript
{
    FMars_Gauntlet_Mourner_ChefPlate_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Mourner_ChefPlate_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Mourner_ChefPlate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        return FMars_Gauntlet_Mourner_ChefPlate_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize, InDecalTexture);
    }
}

USTRUCT()
struct FMars_Gauntlet_Mourner_PackPlate_EntityScript_SpawnParams
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

    UPROPERTY()
    TSoftObjectPtr<UTexture2D> DecalTexture = nullptr;

    FMars_Gauntlet_Mourner_PackPlate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
        DecalTexture = InDecalTexture;
    }
}

namespace UMars_Gauntlet_Mourner_PackPlate_EntityScript
{
    FMars_Gauntlet_Mourner_PackPlate_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Mourner_PackPlate_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Mourner_PackPlate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        return FMars_Gauntlet_Mourner_PackPlate_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize, InDecalTexture);
    }
}

USTRUCT()
struct FMars_Gauntlet_Porter_Chain_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::ManuallyCompleted, 1.5f, EMars_Control_Behavior::Momentary, 0.25f, false, FMars_Control_Manipulation_Spec(FVector(0.0, 0.0, -1.0), 0.029999999329447746f, 0.8500000238418579f, 60.0f, 12.0f, true));

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PullDistance = 40.0f;

    UPROPERTY()
    float32 ChainLength = 110.0f;

    UPROPERTY()
    float32 MoveDuration = 0.30000001192092896f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull chain");

    FMars_Gauntlet_Porter_Chain_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PullDistance = InPullDistance;
        ChainLength = InChainLength;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Gauntlet_Porter_Chain_EntityScript
{
    FMars_Gauntlet_Porter_Chain_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Porter_Chain_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Porter_Chain_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Gauntlet_Porter_Chain_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPullDistance, InChainLength, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Gauntlet_Porter_Gate_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Bars;

    UPROPERTY()
    bool WaitsForClearThreshold = true;

    FMars_Gauntlet_Porter_Gate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Gauntlet_Porter_Gate_EntityScript
{
    FMars_Gauntlet_Porter_Gate_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Porter_Gate_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Porter_Gate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Gauntlet_Porter_Gate_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Gauntlet_Porter_Lamps_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Countdown_Spec Countdown = FMars_Countdown_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    FMars_Gauntlet_Porter_Lamps_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Countdown = InCountdown;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Gauntlet_Porter_Lamps_EntityScript
{
    FMars_Gauntlet_Porter_Lamps_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Porter_Lamps_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Porter_Lamps_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Gauntlet_Porter_Lamps_EntityScript_SpawnParams(InSpawnTransform, InCountdown, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Gauntlet_Porter_PackInside_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trigger_Spec Trigger;

    UPROPERTY()
    FMars_Occupancy_Spec Occupancy = FMars_Occupancy_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    FMars_Gauntlet_Porter_PackInside_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
    }
}

namespace UMars_Gauntlet_Porter_PackInside_EntityScript
{
    FMars_Gauntlet_Porter_PackInside_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Porter_PackInside_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Porter_PackInside_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Gauntlet_Porter_PackInside_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource);
    }
}

USTRUCT()
struct FMars_Gauntlet_Porter_Slab_EntityScript_SpawnParams
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

    UPROPERTY()
    TSoftObjectPtr<UTexture2D> DecalTexture = nullptr;

    FMars_Gauntlet_Porter_Slab_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
        DecalTexture = InDecalTexture;
    }
}

namespace UMars_Gauntlet_Porter_Slab_EntityScript
{
    FMars_Gauntlet_Porter_Slab_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Porter_Slab_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Porter_Slab_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        return FMars_Gauntlet_Porter_Slab_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize, InDecalTexture);
    }
}

USTRUCT()
struct FMars_Gauntlet_Root_EntityScript_SpawnParams
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

    FMars_Gauntlet_Root_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Gauntlet_Root_EntityScript
{
    FMars_Gauntlet_Root_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Root_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Root_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Gauntlet_Root_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_Gauntlet_Salt_EntityScript_SpawnParams
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

    FMars_Gauntlet_Salt_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Gauntlet_Salt_EntityScript
{
    FMars_Gauntlet_Salt_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Salt_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Salt_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Gauntlet_Salt_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_Gauntlet_Truffle_EntityScript_SpawnParams
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

    FMars_Gauntlet_Truffle_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Gauntlet_Truffle_EntityScript
{
    FMars_Gauntlet_Truffle_EntityScript_SpawnParams Params()
    {
        return FMars_Gauntlet_Truffle_EntityScript_SpawnParams();
    }

    FMars_Gauntlet_Truffle_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Gauntlet_Truffle_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_HandWheel_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Timed, 2.0f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec());

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
struct FMars_Ladder_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Ladder_Spec Ladder = FMars_Ladder_Spec();

    FMars_Ladder_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Ladder_Spec InLadder)
    {
        SpawnTransform = InSpawnTransform;
        Ladder = InLadder;
    }
}

namespace UMars_Ladder_EntityScript
{
    FMars_Ladder_EntityScript_SpawnParams Params()
    {
        return FMars_Ladder_EntityScript_SpawnParams();
    }

    FMars_Ladder_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Ladder_Spec InLadder)
    {
        return FMars_Ladder_EntityScript_SpawnParams(InSpawnTransform, InLadder);
    }
}

USTRUCT()
struct FMars_LampBank_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Countdown_Spec Countdown = FMars_Countdown_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_LampBank_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Countdown = InCountdown;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_LampBank_EntityScript
{
    FMars_LampBank_EntityScript_SpawnParams Params()
    {
        return FMars_LampBank_EntityScript_SpawnParams();
    }

    FMars_LampBank_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_LampBank_EntityScript_SpawnParams(InSpawnTransform, InCountdown, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Lever_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec(FVector(-1.0, 0.0, 0.0), 0.019999999552965164f, 0.8500000238418579f, 60.0f, 12.0f, false));

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
struct FMars_OccupancyVolume_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Trigger_Spec Trigger;

    UPROPERTY()
    FMars_Occupancy_Spec Occupancy = FMars_Occupancy_Spec();

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    FMars_OccupancyVolume_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
    }
}

namespace UMars_OccupancyVolume_EntityScript
{
    FMars_OccupancyVolume_EntityScript_SpawnParams Params()
    {
        return FMars_OccupancyVolume_EntityScript_SpawnParams();
    }

    FMars_OccupancyVolume_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource)
    {
        return FMars_OccupancyVolume_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource);
    }
}

USTRUCT()
struct FMars_Pendulum_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Oscillator_Spec Oscillator;

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

    UPROPERTY()
    TSoftObjectPtr<UTexture2D> DecalTexture = nullptr;

    FMars_PressurePlate_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
        DecalTexture = InDecalTexture;
    }
}

namespace UMars_PressurePlate_EntityScript
{
    FMars_PressurePlate_EntityScript_SpawnParams Params()
    {
        return FMars_PressurePlate_EntityScript_SpawnParams();
    }

    FMars_PressurePlate_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        return FMars_PressurePlate_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize, InDecalTexture);
    }
}

USTRUCT()
struct FMars_PullChain_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::ManuallyCompleted, 1.5f, EMars_Control_Behavior::Momentary, 0.25f, false, FMars_Control_Manipulation_Spec(FVector(0.0, 0.0, -1.0), 0.029999999329447746f, 0.8500000238418579f, 60.0f, 12.0f, true));

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    float32 PullDistance = 40.0f;

    UPROPERTY()
    float32 ChainLength = 110.0f;

    UPROPERTY()
    float32 MoveDuration = 0.30000001192092896f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull chain");

    FMars_PullChain_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PullDistance = InPullDistance;
        ChainLength = InChainLength;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_PullChain_EntityScript
{
    FMars_PullChain_EntityScript_SpawnParams Params()
    {
        return FMars_PullChain_EntityScript_SpawnParams();
    }

    FMars_PullChain_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_PullChain_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPullDistance, InChainLength, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_BackpackPlateF_EntityScript_SpawnParams
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

    UPROPERTY()
    TSoftObjectPtr<UTexture2D> DecalTexture = nullptr;

    FMars_Sandbox_BackpackPlateF_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
        DecalTexture = InDecalTexture;
    }
}

namespace UMars_Sandbox_BackpackPlateF_EntityScript
{
    FMars_Sandbox_BackpackPlateF_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_BackpackPlateF_EntityScript_SpawnParams();
    }

    FMars_Sandbox_BackpackPlateF_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        return FMars_Sandbox_BackpackPlateF_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize, InDecalTexture);
    }
}

USTRUCT()
struct FMars_Sandbox_ChainL_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::ManuallyCompleted, 1.5f, EMars_Control_Behavior::Momentary, 0.25f, false, FMars_Control_Manipulation_Spec(FVector(0.0, 0.0, -1.0), 0.029999999329447746f, 0.8500000238418579f, 60.0f, 12.0f, true));

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PullDistance = 40.0f;

    UPROPERTY()
    float32 ChainLength = 110.0f;

    UPROPERTY()
    float32 MoveDuration = 0.30000001192092896f;

    UPROPERTY()
    FText PromptText = FText::FromString("Pull chain");

    FMars_Sandbox_ChainL_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PullDistance = InPullDistance;
        ChainLength = InChainLength;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_ChainL_EntityScript
{
    FMars_Sandbox_ChainL_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_ChainL_EntityScript_SpawnParams();
    }

    FMars_Sandbox_ChainL_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPullDistance, float32 InChainLength, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Sandbox_ChainL_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPullDistance, InChainLength, InMoveDuration, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_Cleaver_EntityScript_SpawnParams
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

    FMars_Sandbox_Cleaver_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Sandbox_Cleaver_EntityScript
{
    FMars_Sandbox_Cleaver_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_Cleaver_EntityScript_SpawnParams();
    }

    FMars_Sandbox_Cleaver_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Sandbox_Cleaver_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_Sandbox_Crawler4_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Crawler_Spec Spec;

    UPROPERTY()
    FLinearColor Color = FLinearColor(0.75f, 0.3499999940395355f, 0.20000000298023224f, 1.0f);

    UPROPERTY()
    bool WithVisuals = true;

    FMars_Sandbox_Crawler4_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals)
    {
        SpawnTransform = InSpawnTransform;
        Spec = InSpec;
        Color = InColor;
        WithVisuals = InWithVisuals;
    }
}

namespace UMars_Sandbox_Crawler4_EntityScript
{
    FMars_Sandbox_Crawler4_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_Crawler4_EntityScript_SpawnParams();
    }

    FMars_Sandbox_Crawler4_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals)
    {
        return FMars_Sandbox_Crawler4_EntityScript_SpawnParams(InSpawnTransform, InSpec, InColor, InWithVisuals);
    }
}

USTRUCT()
struct FMars_Sandbox_Crawler6_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Crawler_Spec Spec;

    UPROPERTY()
    FLinearColor Color = FLinearColor(0.75f, 0.3499999940395355f, 0.20000000298023224f, 1.0f);

    UPROPERTY()
    bool WithVisuals = true;

    FMars_Sandbox_Crawler6_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals)
    {
        SpawnTransform = InSpawnTransform;
        Spec = InSpec;
        Color = InColor;
        WithVisuals = InWithVisuals;
    }
}

namespace UMars_Sandbox_Crawler6_EntityScript
{
    FMars_Sandbox_Crawler6_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_Crawler6_EntityScript_SpawnParams();
    }

    FMars_Sandbox_Crawler6_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals)
    {
        return FMars_Sandbox_Crawler6_EntityScript_SpawnParams(InSpawnTransform, InSpec, InColor, InWithVisuals);
    }
}

USTRUCT()
struct FMars_Sandbox_GateA_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Sandbox_GateA_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Sandbox_GateA_EntityScript
{
    FMars_Sandbox_GateA_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateA_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateA_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Sandbox_GateA_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Sandbox_GateB_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Sandbox_GateB_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Sandbox_GateB_EntityScript
{
    FMars_Sandbox_GateB_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateB_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateB_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Sandbox_GateB_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Sandbox_GateC_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Sandbox_GateC_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Sandbox_GateC_EntityScript
{
    FMars_Sandbox_GateC_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateC_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateC_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Sandbox_GateC_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Sandbox_GateF_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Sandbox_GateF_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Sandbox_GateF_EntityScript
{
    FMars_Sandbox_GateF_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateF_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateF_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Sandbox_GateF_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Sandbox_GateI_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Sandbox_GateI_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Sandbox_GateI_EntityScript
{
    FMars_Sandbox_GateI_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateI_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateI_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Sandbox_GateI_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Sandbox_GateM_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Gate_Spec Gate;

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    UPROPERTY()
    bool WaitsForClearThreshold = false;

    FMars_Sandbox_GateM_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        SpawnTransform = InSpawnTransform;
        Gate = InGate;
        Sink = InSink;
        Source = InSource;
        Leaf = InLeaf;
        WaitsForClearThreshold = InWaitsForClearThreshold;
    }
}

namespace UMars_Sandbox_GateM_EntityScript
{
    FMars_Sandbox_GateM_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_GateM_EntityScript_SpawnParams();
    }

    FMars_Sandbox_GateM_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Gate_Spec InGate, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource, EMars_Gate_Leaf InLeaf, bool InWaitsForClearThreshold)
    {
        return FMars_Sandbox_GateM_EntityScript_SpawnParams(InSpawnTransform, InGate, InSink, InSource, InLeaf, InWaitsForClearThreshold);
    }
}

USTRUCT()
struct FMars_Sandbox_LampsL_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Countdown_Spec Countdown = FMars_Countdown_Spec();

    UPROPERTY()
    FMars_MechanismSink_Spec Sink;

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    FMars_Sandbox_LampsL_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        SpawnTransform = InSpawnTransform;
        Countdown = InCountdown;
        Sink = InSink;
        Source = InSource;
    }
}

namespace UMars_Sandbox_LampsL_EntityScript
{
    FMars_Sandbox_LampsL_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_LampsL_EntityScript_SpawnParams();
    }

    FMars_Sandbox_LampsL_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Countdown_Spec InCountdown, FMars_MechanismSink_Spec InSink, FMars_MechanismSource_Spec InSource)
    {
        return FMars_Sandbox_LampsL_EntityScript_SpawnParams(InSpawnTransform, InCountdown, InSink, InSource);
    }
}

USTRUCT()
struct FMars_Sandbox_LeverA_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec(FVector(-1.0, 0.0, 0.0), 0.019999999552965164f, 0.8500000238418579f, 60.0f, 12.0f, false));

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.3499999940395355f;

    UPROPERTY()
    FText PromptText = FText::FromString("Grip lever");

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
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec(FVector(-1.0, 0.0, 0.0), 0.019999999552965164f, 0.8500000238418579f, 60.0f, 12.0f, false));

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.3499999940395355f;

    UPROPERTY()
    FText PromptText = FText::FromString("Grip lever");

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
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec(FVector(-1.0, 0.0, 0.0), 0.019999999552965164f, 0.8500000238418579f, 60.0f, 12.0f, false));

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.3499999940395355f;

    UPROPERTY()
    FText PromptText = FText::FromString("Grip lever");

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
struct FMars_Sandbox_NavField_EntityScript_SpawnParams
{
    UPROPERTY()
    FCk_GroundNavVolume_Spec _Params;

    UPROPERTY()
    FTransform _SpawnTransform = FTransform::Identity;

    FMars_Sandbox_NavField_EntityScript_SpawnParams(FCk_GroundNavVolume_Spec In_Params, FTransform In_SpawnTransform)
    {
        _Params = In_Params;
        _SpawnTransform = In_SpawnTransform;
    }
}

namespace UMars_Sandbox_NavField_EntityScript
{
    FMars_Sandbox_NavField_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_NavField_EntityScript_SpawnParams();
    }

    FMars_Sandbox_NavField_EntityScript_SpawnParams Params(FCk_GroundNavVolume_Spec In_Params, FTransform In_SpawnTransform)
    {
        return FMars_Sandbox_NavField_EntityScript_SpawnParams(In_Params, In_SpawnTransform);
    }
}

USTRUCT()
struct FMars_Sandbox_Pendulum_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Oscillator_Spec Oscillator;

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

    UPROPERTY()
    TSoftObjectPtr<UTexture2D> DecalTexture = nullptr;

    FMars_Sandbox_PlateF_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        SpawnTransform = InSpawnTransform;
        Trigger = InTrigger;
        Occupancy = InOccupancy;
        Source = InSource;
        PlateSize = InPlateSize;
        DecalTexture = InDecalTexture;
    }
}

namespace UMars_Sandbox_PlateF_EntityScript
{
    FMars_Sandbox_PlateF_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_PlateF_EntityScript_SpawnParams();
    }

    FMars_Sandbox_PlateF_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Trigger_Spec InTrigger, FMars_Occupancy_Spec InOccupancy, FMars_MechanismSource_Spec InSource, FVector InPlateSize, TSoftObjectPtr<UTexture2D> InDecalTexture)
    {
        return FMars_Sandbox_PlateF_EntityScript_SpawnParams(InSpawnTransform, InTrigger, InOccupancy, InSource, InPlateSize, InDecalTexture);
    }
}

USTRUCT()
struct FMars_Sandbox_SealG_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(0.10000000149011612f, 0.3499999940395355f, 1.0f, 1.0f);

    UPROPERTY()
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Square;

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Sandbox_SealG_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        Glyph = InGlyph;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_SealG_EntityScript
{
    FMars_Sandbox_SealG_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SealG_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SealG_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        return FMars_Sandbox_SealG_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InGlyph, InPromptText);
    }
}

USTRUCT()
struct FMars_Sandbox_SealH_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source;

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(1.0f, 0.44999998807907104f, 0.05000000074505806f, 1.0f);

    UPROPERTY()
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Square;

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Sandbox_SealH_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        Glyph = InGlyph;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_SealH_EntityScript
{
    FMars_Sandbox_SealH_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_SealH_EntityScript_SpawnParams();
    }

    FMars_Sandbox_SealH_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        return FMars_Sandbox_SealH_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InGlyph, InPromptText);
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
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 1.0f, false, FMars_Control_Manipulation_Spec());

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
struct FMars_Sandbox_Tenderizer_EntityScript_SpawnParams
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

    FMars_Sandbox_Tenderizer_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Sandbox_Tenderizer_EntityScript
{
    FMars_Sandbox_Tenderizer_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_Tenderizer_EntityScript_SpawnParams();
    }

    FMars_Sandbox_Tenderizer_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Sandbox_Tenderizer_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
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
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Timed, 2.0f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec());

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
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 0.4000000059604645f, false, FMars_Control_Manipulation_Spec());

    UPROPERTY()
    FMars_MechanismSource_Spec Source = FMars_MechanismSource_Spec();

    UPROPERTY()
    FLinearColor GlyphColor = FLinearColor(0.20000000298023224f, 0.800000011920929f, 1.0f, 1.0f);

    UPROPERTY()
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Square;

    UPROPERTY()
    FText PromptText = FText::FromString("Press seal");

    FMars_Seal_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        GlyphColor = InGlyphColor;
        Glyph = InGlyph;
        PromptText = InPromptText;
    }
}

namespace UMars_Seal_EntityScript
{
    FMars_Seal_EntityScript_SpawnParams Params()
    {
        return FMars_Seal_EntityScript_SpawnParams();
    }

    FMars_Seal_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, FLinearColor InGlyphColor, EMars_Seal_Glyph InGlyph, FText InPromptText)
    {
        return FMars_Seal_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InGlyphColor, InGlyph, InPromptText);
    }
}

USTRUCT()
struct FMars_SearingStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    UPROPERTY()
    FMars_Searing_Spec Searing = FMars_Searing_Spec();

    UPROPERTY()
    FMars_Implement_Spec Implement = FMars_Implement_Spec();

    FMars_SearingStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_Searing_Spec InSearing, FMars_Implement_Spec InImplement)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        Searing = InSearing;
        Implement = InImplement;
    }
}

namespace UMars_SearingStation_EntityScript
{
    FMars_SearingStation_EntityScript_SpawnParams Params()
    {
        return FMars_SearingStation_EntityScript_SpawnParams();
    }

    FMars_SearingStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_Searing_Spec InSearing, FMars_Implement_Spec InImplement)
    {
        return FMars_SearingStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InSearing, InImplement);
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
struct FMars_SmCondition_BrainLeaf_SpawnParams
{
}

namespace UMars_SmCondition_BrainLeaf
{
    FMars_SmCondition_BrainLeaf_SpawnParams Params()
    {
        return FMars_SmCondition_BrainLeaf_SpawnParams();
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
struct FMars_SmCondition_Crawler_IsDead_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_IsDead
{
    FMars_SmCondition_Crawler_IsDead_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_IsDead_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_LeafCower_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafCower
{
    FMars_SmCondition_Crawler_LeafCower_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafCower_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_LeafFlinch_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafFlinch
{
    FMars_SmCondition_Crawler_LeafFlinch_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafFlinch_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_LeafNotCower_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafNotCower
{
    FMars_SmCondition_Crawler_LeafNotCower_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafNotCower_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_LeafNotFlinch_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafNotFlinch
{
    FMars_SmCondition_Crawler_LeafNotFlinch_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafNotFlinch_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_LeafNotRoam_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafNotRoam
{
    FMars_SmCondition_Crawler_LeafNotRoam_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafNotRoam_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_LeafRoam_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafRoam
{
    FMars_SmCondition_Crawler_LeafRoam_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafRoam_SpawnParams();
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
struct FMars_SmCondition_HandsPhaseElapsed_SpawnParams
{
}

namespace UMars_SmCondition_HandsPhaseElapsed
{
    FMars_SmCondition_HandsPhaseElapsed_SpawnParams Params()
    {
        return FMars_SmCondition_HandsPhaseElapsed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsPhaseElapsed_Grip_SpawnParams
{
}

namespace UMars_SmCondition_HandsPhaseElapsed_Grip
{
    FMars_SmCondition_HandsPhaseElapsed_Grip_SpawnParams Params()
    {
        return FMars_SmCondition_HandsPhaseElapsed_Grip_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsPhaseElapsed_Push_SpawnParams
{
}

namespace UMars_SmCondition_HandsPhaseElapsed_Push
{
    FMars_SmCondition_HandsPhaseElapsed_Push_SpawnParams Params()
    {
        return FMars_SmCondition_HandsPhaseElapsed_Push_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsPhaseElapsed_Reach_SpawnParams
{
}

namespace UMars_SmCondition_HandsPhaseElapsed_Reach
{
    FMars_SmCondition_HandsPhaseElapsed_Reach_SpawnParams Params()
    {
        return FMars_SmCondition_HandsPhaseElapsed_Reach_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsPhaseElapsed_Release_SpawnParams
{
}

namespace UMars_SmCondition_HandsPhaseElapsed_Release
{
    FMars_SmCondition_HandsPhaseElapsed_Release_SpawnParams Params()
    {
        return FMars_SmCondition_HandsPhaseElapsed_Release_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsPhaseElapsed_Return_SpawnParams
{
}

namespace UMars_SmCondition_HandsPhaseElapsed_Return
{
    FMars_SmCondition_HandsPhaseElapsed_Return_SpawnParams Params()
    {
        return FMars_SmCondition_HandsPhaseElapsed_Return_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsPushRequested_SpawnParams
{
}

namespace UMars_SmCondition_HandsPushRequested
{
    FMars_SmCondition_HandsPushRequested_SpawnParams Params()
    {
        return FMars_SmCondition_HandsPushRequested_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsReachRequested_SpawnParams
{
}

namespace UMars_SmCondition_HandsReachRequested
{
    FMars_SmCondition_HandsReachRequested_SpawnParams Params()
    {
        return FMars_SmCondition_HandsReachRequested_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsReachRequested_Instant_SpawnParams
{
}

namespace UMars_SmCondition_HandsReachRequested_Instant
{
    FMars_SmCondition_HandsReachRequested_Instant_SpawnParams Params()
    {
        return FMars_SmCondition_HandsReachRequested_Instant_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsReachRequested_Timed_SpawnParams
{
}

namespace UMars_SmCondition_HandsReachRequested_Timed
{
    FMars_SmCondition_HandsReachRequested_Timed_SpawnParams Params()
    {
        return FMars_SmCondition_HandsReachRequested_Timed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_HandsTargetLost_SpawnParams
{
}

namespace UMars_SmCondition_HandsTargetLost
{
    FMars_SmCondition_HandsTargetLost_SpawnParams Params()
    {
        return FMars_SmCondition_HandsTargetLost_SpawnParams();
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
struct FMars_SmCondition_IsClimbing_SpawnParams
{
}

namespace UMars_SmCondition_IsClimbing
{
    FMars_SmCondition_IsClimbing_SpawnParams Params()
    {
        return FMars_SmCondition_IsClimbing_SpawnParams();
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
struct FMars_SmCondition_IsNotClimbing_SpawnParams
{
}

namespace UMars_SmCondition_IsNotClimbing
{
    FMars_SmCondition_IsNotClimbing_SpawnParams Params()
    {
        return FMars_SmCondition_IsNotClimbing_SpawnParams();
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
struct FMars_SmCondition_IsNotOperating_SpawnParams
{
}

namespace UMars_SmCondition_IsNotOperating
{
    FMars_SmCondition_IsNotOperating_SpawnParams Params()
    {
        return FMars_SmCondition_IsNotOperating_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IsOperating_SpawnParams
{
}

namespace UMars_SmCondition_IsOperating
{
    FMars_SmCondition_IsOperating_SpawnParams Params()
    {
        return FMars_SmCondition_IsOperating_SpawnParams();
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
struct FMars_SmCondition_SprintPressed_SpawnParams
{
}

namespace UMars_SmCondition_SprintPressed
{
    FMars_SmCondition_SprintPressed_SpawnParams Params()
    {
        return FMars_SmCondition_SprintPressed_SpawnParams();
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
struct FMars_SmCondition_Station_ReserveConfirmed_SpawnParams
{
}

namespace UMars_SmCondition_Station_ReserveConfirmed
{
    FMars_SmCondition_Station_ReserveConfirmed_SpawnParams Params()
    {
        return FMars_SmCondition_Station_ReserveConfirmed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Station_ReserveRejected_SpawnParams
{
}

namespace UMars_SmCondition_Station_ReserveRejected
{
    FMars_SmCondition_Station_ReserveRejected_SpawnParams Params()
    {
        return FMars_SmCondition_Station_ReserveRejected_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Station_ReserveTimeout_SpawnParams
{
}

namespace UMars_SmCondition_Station_ReserveTimeout
{
    FMars_SmCondition_Station_ReserveTimeout_SpawnParams Params()
    {
        return FMars_SmCondition_Station_ReserveTimeout_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_StationIsNotOperated_SpawnParams
{
}

namespace UMars_SmCondition_StationIsNotOperated
{
    FMars_SmCondition_StationIsNotOperated_SpawnParams Params()
    {
        return FMars_SmCondition_StationIsNotOperated_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_StationIsOperated_SpawnParams
{
}

namespace UMars_SmCondition_StationIsOperated
{
    FMars_SmCondition_StationIsOperated_SpawnParams Params()
    {
        return FMars_SmCondition_StationIsOperated_SpawnParams();
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
struct FMars_SmState_CampUiStation_Open_SpawnParams
{
}

namespace UMars_SmState_CampUiStation_Open
{
    FMars_SmState_CampUiStation_Open_SpawnParams Params()
    {
        return FMars_SmState_CampUiStation_Open_SpawnParams();
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
struct FMars_SmState_Crawler_Alive_SpawnParams
{
}

namespace UMars_SmState_Crawler_Alive
{
    FMars_SmState_Crawler_Alive_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Alive_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Cower_SpawnParams
{
}

namespace UMars_SmState_Crawler_Cower
{
    FMars_SmState_Crawler_Cower_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Cower_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Dead_SpawnParams
{
}

namespace UMars_SmState_Crawler_Dead
{
    FMars_SmState_Crawler_Dead_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Dead_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Flinch_SpawnParams
{
}

namespace UMars_SmState_Crawler_Flinch
{
    FMars_SmState_Crawler_Flinch_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Flinch_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Idle_SpawnParams
{
}

namespace UMars_SmState_Crawler_Idle
{
    FMars_SmState_Crawler_Idle_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Roam_SpawnParams
{
}

namespace UMars_SmState_Crawler_Roam
{
    FMars_SmState_Crawler_Roam_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Roam_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Dicing_Idle_SpawnParams
{
}

namespace UMars_SmState_Dicing_Idle
{
    FMars_SmState_Dicing_Idle_SpawnParams Params()
    {
        return FMars_SmState_Dicing_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Dicing_Operated_SpawnParams
{
}

namespace UMars_SmState_Dicing_Operated
{
    FMars_SmState_Dicing_Operated_SpawnParams Params()
    {
        return FMars_SmState_Dicing_Operated_SpawnParams();
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
struct FMars_SmState_Hands_Grip_SpawnParams
{
}

namespace UMars_SmState_Hands_Grip
{
    FMars_SmState_Hands_Grip_SpawnParams Params()
    {
        return FMars_SmState_Hands_Grip_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Hands_Hold_SpawnParams
{
}

namespace UMars_SmState_Hands_Hold
{
    FMars_SmState_Hands_Hold_SpawnParams Params()
    {
        return FMars_SmState_Hands_Hold_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Hands_Push_SpawnParams
{
}

namespace UMars_SmState_Hands_Push
{
    FMars_SmState_Hands_Push_SpawnParams Params()
    {
        return FMars_SmState_Hands_Push_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Hands_Reach_SpawnParams
{
}

namespace UMars_SmState_Hands_Reach
{
    FMars_SmState_Hands_Reach_SpawnParams Params()
    {
        return FMars_SmState_Hands_Reach_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Hands_Release_SpawnParams
{
}

namespace UMars_SmState_Hands_Release
{
    FMars_SmState_Hands_Release_SpawnParams Params()
    {
        return FMars_SmState_Hands_Release_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Hands_Rest_SpawnParams
{
}

namespace UMars_SmState_Hands_Rest
{
    FMars_SmState_Hands_Rest_SpawnParams Params()
    {
        return FMars_SmState_Hands_Rest_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Hands_Return_SpawnParams
{
}

namespace UMars_SmState_Hands_Return
{
    FMars_SmState_Hands_Return_SpawnParams Params()
    {
        return FMars_SmState_Hands_Return_SpawnParams();
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
struct FMars_SmState_ItemUse_Strike_SpawnParams
{
}

namespace UMars_SmState_ItemUse_Strike
{
    FMars_SmState_ItemUse_Strike_SpawnParams Params()
    {
        return FMars_SmState_ItemUse_Strike_SpawnParams();
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
struct FMars_SmState_Loco_Climb_SpawnParams
{
}

namespace UMars_SmState_Loco_Climb
{
    FMars_SmState_Loco_Climb_SpawnParams Params()
    {
        return FMars_SmState_Loco_Climb_SpawnParams();
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
struct FMars_SmState_Operating_SpawnParams
{
}

namespace UMars_SmState_Operating
{
    FMars_SmState_Operating_SpawnParams Params()
    {
        return FMars_SmState_Operating_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Searing_Idle_SpawnParams
{
}

namespace UMars_SmState_Searing_Idle
{
    FMars_SmState_Searing_Idle_SpawnParams Params()
    {
        return FMars_SmState_Searing_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Searing_Operated_SpawnParams
{
}

namespace UMars_SmState_Searing_Operated
{
    FMars_SmState_Searing_Operated_SpawnParams Params()
    {
        return FMars_SmState_Searing_Operated_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Station_Grip_SpawnParams
{
}

namespace UMars_SmState_Station_Grip
{
    FMars_SmState_Station_Grip_SpawnParams Params()
    {
        return FMars_SmState_Station_Grip_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Station_Use_SpawnParams
{
}

namespace UMars_SmState_Station_Use
{
    FMars_SmState_Station_Use_SpawnParams Params()
    {
        return FMars_SmState_Station_Use_SpawnParams();
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
struct FMars_SmTask_CampUiStation_Open_SpawnParams
{
}

namespace UMars_SmTask_CampUiStation_Open
{
    FMars_SmTask_CampUiStation_Open_SpawnParams Params()
    {
        return FMars_SmTask_CampUiStation_Open_SpawnParams();
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
struct FMars_SmTask_ClimberMountIntent_SpawnParams
{
}

namespace UMars_SmTask_ClimberMountIntent
{
    FMars_SmTask_ClimberMountIntent_SpawnParams Params()
    {
        return FMars_SmTask_ClimberMountIntent_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_ClimbInput_SpawnParams
{
}

namespace UMars_SmTask_ClimbInput
{
    FMars_SmTask_ClimbInput_SpawnParams Params()
    {
        return FMars_SmTask_ClimbInput_SpawnParams();
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
struct FMars_SmTask_Crawler_BehaviorSubSm_SpawnParams
{
}

namespace UMars_SmTask_Crawler_BehaviorSubSm
{
    FMars_SmTask_Crawler_BehaviorSubSm_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_BehaviorSubSm_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_Cower_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Cower
{
    FMars_SmTask_Crawler_Cower_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Cower_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_Die_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Die
{
    FMars_SmTask_Crawler_Die_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Die_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_Flinch_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Flinch
{
    FMars_SmTask_Crawler_Flinch_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Flinch_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_Roam_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Roam
{
    FMars_SmTask_Crawler_Roam_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Roam_SpawnParams();
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
struct FMars_SmTask_Dicing_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_Dicing_OperatorHints
{
    FMars_SmTask_Dicing_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_Dicing_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Dicing_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_Dicing_OperatorInput
{
    FMars_SmTask_Dicing_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_Dicing_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Dicing_ResetOnEnter_SpawnParams
{
}

namespace UMars_SmTask_Dicing_ResetOnEnter
{
    FMars_SmTask_Dicing_ResetOnEnter_SpawnParams Params()
    {
        return FMars_SmTask_Dicing_ResetOnEnter_SpawnParams();
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
struct FMars_SmTask_EmoteWheelIntent_SpawnParams
{
}

namespace UMars_SmTask_EmoteWheelIntent
{
    FMars_SmTask_EmoteWheelIntent_SpawnParams Params()
    {
        return FMars_SmTask_EmoteWheelIntent_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase
{
    FMars_SmTask_Hands_SetPhase_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_Grip_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase_Grip
{
    FMars_SmTask_Hands_SetPhase_Grip_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_Grip_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_Hold_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase_Hold
{
    FMars_SmTask_Hands_SetPhase_Hold_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_Hold_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_None_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase_None
{
    FMars_SmTask_Hands_SetPhase_None_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_None_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_Push_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase_Push
{
    FMars_SmTask_Hands_SetPhase_Push_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_Push_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_Reach_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase_Reach
{
    FMars_SmTask_Hands_SetPhase_Reach_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_Reach_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_Release_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase_Release
{
    FMars_SmTask_Hands_SetPhase_Release_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_Release_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_SetPhase_Return_SpawnParams
{
}

namespace UMars_SmTask_Hands_SetPhase_Return
{
    FMars_SmTask_Hands_SetPhase_Return_SpawnParams Params()
    {
        return FMars_SmTask_Hands_SetPhase_Return_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Hands_StopEmote_SpawnParams
{
}

namespace UMars_SmTask_Hands_StopEmote
{
    FMars_SmTask_Hands_StopEmote_SpawnParams Params()
    {
        return FMars_SmTask_Hands_StopEmote_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HandsLaunchBinds_SpawnParams
{
}

namespace UMars_SmTask_HandsLaunchBinds
{
    FMars_SmTask_HandsLaunchBinds_SpawnParams Params()
    {
        return FMars_SmTask_HandsLaunchBinds_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HandsResolverBinds_SpawnParams
{
}

namespace UMars_SmTask_HandsResolverBinds
{
    FMars_SmTask_HandsResolverBinds_SpawnParams Params()
    {
        return FMars_SmTask_HandsResolverBinds_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HandsResolverBinds_NoResync_SpawnParams
{
}

namespace UMars_SmTask_HandsResolverBinds_NoResync
{
    FMars_SmTask_HandsResolverBinds_NoResync_SpawnParams Params()
    {
        return FMars_SmTask_HandsResolverBinds_NoResync_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_HandsSubSm_SpawnParams
{
}

namespace UMars_SmTask_HandsSubSm
{
    FMars_SmTask_HandsSubSm_SpawnParams Params()
    {
        return FMars_SmTask_HandsSubSm_SpawnParams();
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
struct FMars_SmTask_Interactable_HandsGate_SpawnParams
{
}

namespace UMars_SmTask_Interactable_HandsGate
{
    FMars_SmTask_Interactable_HandsGate_SpawnParams Params()
    {
        return FMars_SmTask_Interactable_HandsGate_SpawnParams();
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
struct FMars_SmTask_ItemUse_Strike_SpawnParams
{
}

namespace UMars_SmTask_ItemUse_Strike
{
    FMars_SmTask_ItemUse_Strike_SpawnParams Params()
    {
        return FMars_SmTask_ItemUse_Strike_SpawnParams();
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
struct FMars_SmTask_ManipulateControl_SpawnParams
{
}

namespace UMars_SmTask_ManipulateControl
{
    FMars_SmTask_ManipulateControl_SpawnParams Params()
    {
        return FMars_SmTask_ManipulateControl_SpawnParams();
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
struct FMars_SmTask_Operating_Camera_SpawnParams
{
}

namespace UMars_SmTask_Operating_Camera
{
    FMars_SmTask_Operating_Camera_SpawnParams Params()
    {
        return FMars_SmTask_Operating_Camera_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Operating_Grip_SpawnParams
{
}

namespace UMars_SmTask_Operating_Grip
{
    FMars_SmTask_Operating_Grip_SpawnParams Params()
    {
        return FMars_SmTask_Operating_Grip_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Operating_Hints_SpawnParams
{
}

namespace UMars_SmTask_Operating_Hints
{
    FMars_SmTask_Operating_Hints_SpawnParams Params()
    {
        return FMars_SmTask_Operating_Hints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Operating_LeaveIntent_SpawnParams
{
}

namespace UMars_SmTask_Operating_LeaveIntent
{
    FMars_SmTask_Operating_LeaveIntent_SpawnParams Params()
    {
        return FMars_SmTask_Operating_LeaveIntent_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Operating_PoseLock_SpawnParams
{
}

namespace UMars_SmTask_Operating_PoseLock
{
    FMars_SmTask_Operating_PoseLock_SpawnParams Params()
    {
        return FMars_SmTask_Operating_PoseLock_SpawnParams();
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
struct FMars_SmTask_Searing_HeatOnEnter_SpawnParams
{
}

namespace UMars_SmTask_Searing_HeatOnEnter
{
    FMars_SmTask_Searing_HeatOnEnter_SpawnParams Params()
    {
        return FMars_SmTask_Searing_HeatOnEnter_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Searing_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_Searing_OperatorHints
{
    FMars_SmTask_Searing_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_Searing_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Searing_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_Searing_OperatorInput
{
    FMars_SmTask_Searing_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_Searing_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Searing_ResetOnEnter_SpawnParams
{
}

namespace UMars_SmTask_Searing_ResetOnEnter
{
    FMars_SmTask_Searing_ResetOnEnter_SpawnParams Params()
    {
        return FMars_SmTask_Searing_ResetOnEnter_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Station_RequestReserve_SpawnParams
{
}

namespace UMars_SmTask_Station_RequestReserve
{
    FMars_SmTask_Station_RequestReserve_SpawnParams Params()
    {
        return FMars_SmTask_Station_RequestReserve_SpawnParams();
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
    FMars_Control_Spec Control = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Momentary, 1.0f, false, FMars_Control_Manipulation_Spec());

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
struct FMars_TargetDummy_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 MaxHealth = 100.0f;

    UPROPERTY()
    float32 RearmSeconds = 5.0f;

    FMars_TargetDummy_EntityScript_SpawnParams(FTransform InSpawnTransform, float32 InMaxHealth, float32 InRearmSeconds)
    {
        SpawnTransform = InSpawnTransform;
        MaxHealth = InMaxHealth;
        RearmSeconds = InRearmSeconds;
    }
}

namespace UMars_TargetDummy_EntityScript
{
    FMars_TargetDummy_EntityScript_SpawnParams Params()
    {
        return FMars_TargetDummy_EntityScript_SpawnParams();
    }

    FMars_TargetDummy_EntityScript_SpawnParams Params(FTransform InSpawnTransform, float32 InMaxHealth, float32 InRearmSeconds)
    {
        return FMars_TargetDummy_EntityScript_SpawnParams(InSpawnTransform, InMaxHealth, InRearmSeconds);
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
struct FMars_WorkbenchStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    FMars_WorkbenchStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
    }
}

namespace UMars_WorkbenchStation_EntityScript
{
    FMars_WorkbenchStation_EntityScript_SpawnParams Params()
    {
        return FMars_WorkbenchStation_EntityScript_SpawnParams();
    }

    FMars_WorkbenchStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation)
    {
        return FMars_WorkbenchStation_EntityScript_SpawnParams(InSpawnTransform, InStation);
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
struct FMars_WorldItem_Husk_EntityScript_SpawnParams
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

    FMars_WorldItem_Husk_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_WorldItem_Husk_EntityScript
{
    FMars_WorldItem_Husk_EntityScript_SpawnParams Params()
    {
        return FMars_WorldItem_Husk_EntityScript_SpawnParams();
    }

    FMars_WorldItem_Husk_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_WorldItem_Husk_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_WorldItem_Pan_EntityScript_SpawnParams
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

    FMars_WorldItem_Pan_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_WorldItem_Pan_EntityScript
{
    FMars_WorldItem_Pan_EntityScript_SpawnParams Params()
    {
        return FMars_WorldItem_Pan_EntityScript_SpawnParams();
    }

    FMars_WorldItem_Pan_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_WorldItem_Pan_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
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

