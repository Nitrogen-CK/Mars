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
struct FMars_AutoTest_Batter_AdmissionAcceptsAWholeBatterablePiece_SpawnParams
{
}

namespace UMars_AutoTest_Batter_AdmissionAcceptsAWholeBatterablePiece
{
    FMars_AutoTest_Batter_AdmissionAcceptsAWholeBatterablePiece_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_AdmissionAcceptsAWholeBatterablePiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_AdmissionRefusesACutPiece_SpawnParams
{
}

namespace UMars_AutoTest_Batter_AdmissionRefusesACutPiece
{
    FMars_AutoTest_Batter_AdmissionRefusesACutPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_AdmissionRefusesACutPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_AdmissionRefusesAFullBowl_SpawnParams
{
}

namespace UMars_AutoTest_Batter_AdmissionRefusesAFullBowl
{
    FMars_AutoTest_Batter_AdmissionRefusesAFullBowl_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_AdmissionRefusesAFullBowl_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_AdmissionRefusesAnAlreadyBatteredPiece_SpawnParams
{
}

namespace UMars_AutoTest_Batter_AdmissionRefusesAnAlreadyBatteredPiece
{
    FMars_AutoTest_Batter_AdmissionRefusesAnAlreadyBatteredPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_AdmissionRefusesAnAlreadyBatteredPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_AdmissionRefusesANonBatterableFood_SpawnParams
{
}

namespace UMars_AutoTest_Batter_AdmissionRefusesANonBatterableFood
{
    FMars_AutoTest_Batter_AdmissionRefusesANonBatterableFood_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_AdmissionRefusesANonBatterableFood_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_ATakeOutWritesBatteredAndTheTrayReceivesIt_SpawnParams
{
}

namespace UMars_AutoTest_Batter_ATakeOutWritesBatteredAndTheTrayReceivesIt
{
    FMars_AutoTest_Batter_ATakeOutWritesBatteredAndTheTrayReceivesIt_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_ATakeOutWritesBatteredAndTheTrayReceivesIt_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_CoatGrowsOnlyWhileDippedAndNeverFalls_SpawnParams
{
}

namespace UMars_AutoTest_Batter_CoatGrowsOnlyWhileDippedAndNeverFalls
{
    FMars_AutoTest_Batter_CoatGrowsOnlyWhileDippedAndNeverFalls_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_CoatGrowsOnlyWhileDippedAndNeverFalls_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_SpecValidateRejectsBadSpecs_SpawnParams
{
}

namespace UMars_AutoTest_Batter_SpecValidateRejectsBadSpecs
{
    FMars_AutoTest_Batter_SpecValidateRejectsBadSpecs_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_SpecValidateRejectsBadSpecs_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Batter_TakeOutBeforeTheCoatIsCompleteIsRefused_SpawnParams
{
}

namespace UMars_AutoTest_Batter_TakeOutBeforeTheCoatIsCompleteIsRefused
{
    FMars_AutoTest_Batter_TakeOutBeforeTheCoatIsCompleteIsRefused_SpawnParams Params()
    {
        return FMars_AutoTest_Batter_TakeOutBeforeTheCoatIsCompleteIsRefused_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_BatterStation_APlatterSourcedPrepFoodIsBatteredAndWearsItsShell_SpawnParams
{
}

namespace UMars_AutoTest_BatterStation_APlatterSourcedPrepFoodIsBatteredAndWearsItsShell
{
    FMars_AutoTest_BatterStation_APlatterSourcedPrepFoodIsBatteredAndWearsItsShell_SpawnParams Params()
    {
        return FMars_AutoTest_BatterStation_APlatterSourcedPrepFoodIsBatteredAndWearsItsShell_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_BatterStation_LeavingMidCoatKeepsTheBatch_SpawnParams
{
}

namespace UMars_AutoTest_BatterStation_LeavingMidCoatKeepsTheBatch
{
    FMars_AutoTest_BatterStation_LeavingMidCoatKeepsTheBatch_SpawnParams Params()
    {
        return FMars_AutoTest_BatterStation_LeavingMidCoatKeepsTheBatch_SpawnParams();
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
struct FMars_AutoTest_CargoSlot_AFoodItemStowsIntoThePackAndRidesIt_SpawnParams
{
}

namespace UMars_AutoTest_CargoSlot_AFoodItemStowsIntoThePackAndRidesIt
{
    FMars_AutoTest_CargoSlot_AFoodItemStowsIntoThePackAndRidesIt_SpawnParams Params()
    {
        return FMars_AutoTest_CargoSlot_AFoodItemStowsIntoThePackAndRidesIt_SpawnParams();
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
struct FMars_AutoTest_Control_ARefusedReachBeginsTheManipulationAtOnce_SpawnParams
{
}

namespace UMars_AutoTest_Control_ARefusedReachBeginsTheManipulationAtOnce
{
    FMars_AutoTest_Control_ARefusedReachBeginsTheManipulationAtOnce_SpawnParams Params()
    {
        return FMars_AutoTest_Control_ARefusedReachBeginsTheManipulationAtOnce_SpawnParams();
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
struct FMars_AutoTest_Control_HeldGripRocksInsideTheArcUntilRelease_SpawnParams
{
}

namespace UMars_AutoTest_Control_HeldGripRocksInsideTheArcUntilRelease
{
    FMars_AutoTest_Control_HeldGripRocksInsideTheArcUntilRelease_SpawnParams Params()
    {
        return FMars_AutoTest_Control_HeldGripRocksInsideTheArcUntilRelease_SpawnParams();
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
struct FMars_AutoTest_Control_ViewStaysHeldUntilUseReleases_SpawnParams
{
}

namespace UMars_AutoTest_Control_ViewStaysHeldUntilUseReleases
{
    FMars_AutoTest_Control_ViewStaysHeldUntilUseReleases_SpawnParams Params()
    {
        return FMars_AutoTest_Control_ViewStaysHeldUntilUseReleases_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_ACancelPastTheGraspIsANoOp_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_ACancelPastTheGraspIsANoOp
{
    FMars_AutoTest_CookingFeed_ACancelPastTheGraspIsANoOp_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_ACancelPastTheGraspIsANoOp_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix
{
    FMars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_ALongFrameCrossesEachBoundaryOnce_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_ALongFrameCrossesEachBoundaryOnce
{
    FMars_AutoTest_CookingFeed_ALongFrameCrossesEachBoundaryOnce_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_ALongFrameCrossesEachBoundaryOnce_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_AnAdmissionAnswersThroughTheOneSignal_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_AnAdmissionAnswersThroughTheOneSignal
{
    FMars_AutoTest_CookingFeed_AnAdmissionAnswersThroughTheOneSignal_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_AnAdmissionAnswersThroughTheOneSignal_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_AnUnansweredAdmissionSettlesRejectedWithinTheBudget_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_AnUnansweredAdmissionSettlesRejectedWithinTheBudget
{
    FMars_AutoTest_CookingFeed_AnUnansweredAdmissionSettlesRejectedWithinTheBudget_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_AnUnansweredAdmissionSettlesRejectedWithinTheBudget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_AnUndockDuringAwaitAdmissionReturnsThePiece_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_AnUndockDuringAwaitAdmissionReturnsThePiece
{
    FMars_AutoTest_CookingFeed_AnUndockDuringAwaitAdmissionReturnsThePiece_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_AnUndockDuringAwaitAdmissionReturnsThePiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_ARefilledSourceNeverReusesAPieceId_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_ARefilledSourceNeverReusesAPieceId
{
    FMars_AutoTest_CookingFeed_ARefilledSourceNeverReusesAPieceId_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_ARefilledSourceNeverReusesAPieceId_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_ARejectedReleaseReturnsToThePlatterItCameFrom_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_ARejectedReleaseReturnsToThePlatterItCameFrom
{
    FMars_AutoTest_CookingFeed_ARejectedReleaseReturnsToThePlatterItCameFrom_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_ARejectedReleaseReturnsToThePlatterItCameFrom_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_AReleaseLandsInTheStationInbox_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_AReleaseLandsInTheStationInbox
{
    FMars_AutoTest_CookingFeed_AReleaseLandsInTheStationInbox_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_AReleaseLandsInTheStationInbox_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_AReservedPieceTakenOffThePlatterCancelsTheTransfer_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_AReservedPieceTakenOffThePlatterCancelsTheTransfer
{
    FMars_AutoTest_CookingFeed_AReservedPieceTakenOffThePlatterCancelsTheTransfer_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_AReservedPieceTakenOffThePlatterCancelsTheTransfer_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_ChangingTheSourceCancelsAndUnsourcedIsEmpty_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_ChangingTheSourceCancelsAndUnsourcedIsEmpty
{
    FMars_AutoTest_CookingFeed_ChangingTheSourceCancelsAndUnsourcedIsEmpty_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_ChangingTheSourceCancelsAndUnsourcedIsEmpty_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing
{
    FMars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns
{
    FMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_ResetAtEveryPhaseLeavesTheStockOnThePlatter_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_ResetAtEveryPhaseLeavesTheStockOnThePlatter
{
    FMars_AutoTest_CookingFeed_ResetAtEveryPhaseLeavesTheStockOnThePlatter_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_ResetAtEveryPhaseLeavesTheStockOnThePlatter_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_SixPressesDuringOneTransferAdmitOnePiece_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_SixPressesDuringOneTransferAdmitOnePiece
{
    FMars_AutoTest_CookingFeed_SixPressesDuringOneTransferAdmitOnePiece_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_SixPressesDuringOneTransferAdmitOnePiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing
{
    FMars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_TheCarriedPieceRidesTheHandNode_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_TheCarriedPieceRidesTheHandNode
{
    FMars_AutoTest_CookingFeed_TheCarriedPieceRidesTheHandNode_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_TheCarriedPieceRidesTheHandNode_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_TheKernelMovesTheHandNode_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_TheKernelMovesTheHandNode
{
    FMars_AutoTest_CookingFeed_TheKernelMovesTheHandNode_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_TheKernelMovesTheHandNode_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity_SpawnParams
{
}

namespace UMars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity
{
    FMars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity_SpawnParams Params()
    {
        return FMars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity_SpawnParams();
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
struct FMars_AutoTest_CrawlerMelee_AcquireAndLeash_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_AcquireAndLeash
{
    FMars_AutoTest_CrawlerMelee_AcquireAndLeash_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_AcquireAndLeash_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_ActionScopeLoss_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_ActionScopeLoss
{
    FMars_AutoTest_CrawlerMelee_ActionScopeLoss_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_ActionScopeLoss_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_AggressionToggle_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_AggressionToggle
{
    FMars_AutoTest_CrawlerMelee_AggressionToggle_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_AggressionToggle_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_ApproachAndPrepare_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_ApproachAndPrepare
{
    FMars_AutoTest_CrawlerMelee_ApproachAndPrepare_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_ApproachAndPrepare_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_BlockedRoute_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_BlockedRoute
{
    FMars_AutoTest_CrawlerMelee_BlockedRoute_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_BlockedRoute_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_CancelBeforeCommit_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_CancelBeforeCommit
{
    FMars_AutoTest_CrawlerMelee_CancelBeforeCommit_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_CancelBeforeCommit_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_Displacement_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_Displacement
{
    FMars_AutoTest_CrawlerMelee_Displacement_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_Displacement_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_DodgeCommitment_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_DodgeCommitment
{
    FMars_AutoTest_CrawlerMelee_DodgeCommitment_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_DodgeCommitment_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_EngagesAndRetries_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_EngagesAndRetries
{
    FMars_AutoTest_CrawlerMelee_EngagesAndRetries_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_EngagesAndRetries_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_EveryExit_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_EveryExit
{
    FMars_AutoTest_CrawlerMelee_EveryExit_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_EveryExit_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_HitchAndZeroTime_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_HitchAndZeroTime
{
    FMars_AutoTest_CrawlerMelee_HitchAndZeroTime_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_HitchAndZeroTime_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_HitExactlyOnce_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_HitExactlyOnce
{
    FMars_AutoTest_CrawlerMelee_HitExactlyOnce_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_HitExactlyOnce_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_InterruptPriority_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_InterruptPriority
{
    FMars_AutoTest_CrawlerMelee_InterruptPriority_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_InterruptPriority_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_InvalidSpec_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_InvalidSpec
{
    FMars_AutoTest_CrawlerMelee_InvalidSpec_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_InvalidSpec_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_JabThenWalks_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_JabThenWalks
{
    FMars_AutoTest_CrawlerMelee_JabThenWalks_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_JabThenWalks_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbBounds_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbBounds
{
    FMars_AutoTest_CrawlerMelee_LongLimbBounds_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbBounds_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLiveCancel_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLiveCancel
{
    FMars_AutoTest_CrawlerMelee_LongLimbLiveCancel_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLiveCancel_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLiveClear_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLiveClear
{
    FMars_AutoTest_CrawlerMelee_LongLimbLiveClear_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLiveClear_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLiveDamage_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLiveDamage
{
    FMars_AutoTest_CrawlerMelee_LongLimbLiveDamage_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLiveDamage_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLiveScopeLoss_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLiveScopeLoss
{
    FMars_AutoTest_CrawlerMelee_LongLimbLiveScopeLoss_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLiveScopeLoss_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLiveSever_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLiveSever
{
    FMars_AutoTest_CrawlerMelee_LongLimbLiveSever_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLiveSever_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLiveTargetLoss_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLiveTargetLoss
{
    FMars_AutoTest_CrawlerMelee_LongLimbLiveTargetLoss_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLiveTargetLoss_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLiveWall_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLiveWall
{
    FMars_AutoTest_CrawlerMelee_LongLimbLiveWall_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLiveWall_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLoadedBranch_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLoadedBranch
{
    FMars_AutoTest_CrawlerMelee_LongLimbLoadedBranch_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLoadedBranch_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLoadedFastArc_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLoadedFastArc
{
    FMars_AutoTest_CrawlerMelee_LongLimbLoadedFastArc_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLoadedFastArc_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbLoadedProjected_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbLoadedProjected
{
    FMars_AutoTest_CrawlerMelee_LongLimbLoadedProjected_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbLoadedProjected_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_LongLimbTargetBinding_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_LongLimbTargetBinding
{
    FMars_AutoTest_CrawlerMelee_LongLimbTargetBinding_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_LongLimbTargetBinding_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_MissAndCooldown_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_MissAndCooldown
{
    FMars_AutoTest_CrawlerMelee_MissAndCooldown_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_MissAndCooldown_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_Obstruction_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_Obstruction
{
    FMars_AutoTest_CrawlerMelee_Obstruction_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_Obstruction_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PassiveAndNetworkGate_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PassiveAndNetworkGate
{
    FMars_AutoTest_CrawlerMelee_PassiveAndNetworkGate_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PassiveAndNetworkGate_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PhaseSequence_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PhaseSequence
{
    FMars_AutoTest_CrawlerMelee_PhaseSequence_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PhaseSequence_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerCancelledInTheAirThenWalks_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerCancelledInTheAirThenWalks
{
    FMars_AutoTest_CrawlerMelee_PincerCancelledInTheAirThenWalks_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerCancelledInTheAirThenWalks_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerKeyValidation_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerKeyValidation
{
    FMars_AutoTest_CrawlerMelee_PincerKeyValidation_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerKeyValidation_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerNeedsBothClaws_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerNeedsBothClaws
{
    FMars_AutoTest_CrawlerMelee_PincerNeedsBothClaws_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerNeedsBothClaws_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerStrike_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerStrike
{
    FMars_AutoTest_CrawlerMelee_PincerStrike_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerStrike_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerStrikeSixLegs_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerStrikeSixLegs
{
    FMars_AutoTest_CrawlerMelee_PincerStrikeSixLegs_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerStrikeSixLegs_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerStrikeSpider_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerStrikeSpider
{
    FMars_AutoTest_CrawlerMelee_PincerStrikeSpider_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerStrikeSpider_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerThenWalks_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerThenWalks
{
    FMars_AutoTest_CrawlerMelee_PincerThenWalks_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerThenWalks_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerThenWalksSixLegs_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerThenWalksSixLegs
{
    FMars_AutoTest_CrawlerMelee_PincerThenWalksSixLegs_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerThenWalksSixLegs_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PincerThenWalksSpider_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PincerThenWalksSpider
{
    FMars_AutoTest_CrawlerMelee_PincerThenWalksSpider_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PincerThenWalksSpider_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_PrepareTimeout_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_PrepareTimeout
{
    FMars_AutoTest_CrawlerMelee_PrepareTimeout_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_PrepareTimeout_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_QueryPrimitives_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_QueryPrimitives
{
    FMars_AutoTest_CrawlerMelee_QueryPrimitives_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_QueryPrimitives_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_StaleGeneration_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_StaleGeneration
{
    FMars_AutoTest_CrawlerMelee_StaleGeneration_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_StaleGeneration_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_StationaryFacing_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_StationaryFacing
{
    FMars_AutoTest_CrawlerMelee_StationaryFacing_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_StationaryFacing_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CrawlerMelee_TerminalStrikeHit_SpawnParams
{
}

namespace UMars_AutoTest_CrawlerMelee_TerminalStrikeHit
{
    FMars_AutoTest_CrawlerMelee_TerminalStrikeHit_SpawnParams Params()
    {
        return FMars_AutoTest_CrawlerMelee_TerminalStrikeHit_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Cutting_ChopWhileChoppingIsIgnored_SpawnParams
{
}

namespace UMars_AutoTest_Cutting_ChopWhileChoppingIsIgnored
{
    FMars_AutoTest_Cutting_ChopWhileChoppingIsIgnored_SpawnParams Params()
    {
        return FMars_AutoTest_Cutting_ChopWhileChoppingIsIgnored_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Cutting_SpecValidateRejectsANonPositiveBoard_SpawnParams
{
}

namespace UMars_AutoTest_Cutting_SpecValidateRejectsANonPositiveBoard
{
    FMars_AutoTest_Cutting_SpecValidateRejectsANonPositiveBoard_SpawnParams Params()
    {
        return FMars_AutoTest_Cutting_SpecValidateRejectsANonPositiveBoard_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Cutting_TheChopClockIsTheKernels_SpawnParams
{
}

namespace UMars_AutoTest_Cutting_TheChopClockIsTheKernels
{
    FMars_AutoTest_Cutting_TheChopClockIsTheKernels_SpawnParams Params()
    {
        return FMars_AutoTest_Cutting_TheChopClockIsTheKernels_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_ABusyBoardSaysSo_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_ABusyBoardSaysSo
{
    FMars_AutoTest_CuttingStation_ABusyBoardSaysSo_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_ABusyBoardSaysSo_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_AChopCutsEveryPieceItStraddles_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_AChopCutsEveryPieceItStraddles
{
    FMars_AutoTest_CuttingStation_AChopCutsEveryPieceItStraddles_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_AChopCutsEveryPieceItStraddles_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_AChopThatMeetsNoFoodIsMissed_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_AChopThatMeetsNoFoodIsMissed
{
    FMars_AutoTest_CuttingStation_AChopThatMeetsNoFoodIsMissed_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_AChopThatMeetsNoFoodIsMissed_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_ACrossCutAfterATurnPartsAcrossTheFirstCut_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_ACrossCutAfterATurnPartsAcrossTheFirstCut
{
    FMars_AutoTest_CuttingStation_ACrossCutAfterATurnPartsAcrossTheFirstCut_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_ACrossCutAfterATurnPartsAcrossTheFirstCut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_AddFoodBringsTheJointToTheBoard_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_AddFoodBringsTheJointToTheBoard
{
    FMars_AutoTest_CuttingStation_AddFoodBringsTheJointToTheBoard_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_AddFoodBringsTheJointToTheBoard_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_AddFoodIsRefusedWhileTheBoardHoldsAnything_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_AddFoodIsRefusedWhileTheBoardHoldsAnything
{
    FMars_AutoTest_CuttingStation_AddFoodIsRefusedWhileTheBoardHoldsAnything_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_AddFoodIsRefusedWhileTheBoardHoldsAnything_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_AddFoodLandsTheJointWhenTheOperatorLeavesInTheReleaseFrame_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_AddFoodLandsTheJointWhenTheOperatorLeavesInTheReleaseFrame
{
    FMars_AutoTest_CuttingStation_AddFoodLandsTheJointWhenTheOperatorLeavesInTheReleaseFrame_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_AddFoodLandsTheJointWhenTheOperatorLeavesInTheReleaseFrame_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_AJointOnTheBoardCannotBePickedUp_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_AJointOnTheBoardCannotBePickedUp
{
    FMars_AutoTest_CuttingStation_AJointOnTheBoardCannotBePickedUp_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_AJointOnTheBoardCannotBePickedUp_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_APlacedPieceSitsOnThePileNode_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_APlacedPieceSitsOnThePileNode
{
    FMars_AutoTest_CuttingStation_APlacedPieceSitsOnThePileNode_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_APlacedPieceSitsOnThePileNode_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_ASweepRefusedByAFullTrayReplacesThePieces_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_ASweepRefusedByAFullTrayReplacesThePieces
{
    FMars_AutoTest_CuttingStation_ASweepRefusedByAFullTrayReplacesThePieces_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_ASweepRefusedByAFullTrayReplacesThePieces_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_ASweepWithNoTrayKeepsThePiecesOnTheBoard_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_ASweepWithNoTrayKeepsThePiecesOnTheBoard
{
    FMars_AutoTest_CuttingStation_ASweepWithNoTrayKeepsThePiecesOnTheBoard_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_ASweepWithNoTrayKeepsThePiecesOnTheBoard_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_ChopsCutTheJoint_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_ChopsCutTheJoint
{
    FMars_AutoTest_CuttingStation_ChopsCutTheJoint_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_ChopsCutTheJoint_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_FoodDefinitionsFollowTheirMeshes_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_FoodDefinitionsFollowTheirMeshes
{
    FMars_AutoTest_CuttingStation_FoodDefinitionsFollowTheirMeshes_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_FoodDefinitionsFollowTheirMeshes_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_InputDockRefusesACutPlatter_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_InputDockRefusesACutPlatter
{
    FMars_AutoTest_CuttingStation_InputDockRefusesACutPlatter_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_InputDockRefusesACutPlatter_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_InputDockTakesWholeMeatOnly_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_InputDockTakesWholeMeatOnly
{
    FMars_AutoTest_CuttingStation_InputDockTakesWholeMeatOnly_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_InputDockTakesWholeMeatOnly_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_LeaveMidCutKeepsTheHalvesForTheNextOperator_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_LeaveMidCutKeepsTheHalvesForTheNextOperator
{
    FMars_AutoTest_CuttingStation_LeaveMidCutKeepsTheHalvesForTheNextOperator_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_LeaveMidCutKeepsTheHalvesForTheNextOperator_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_MeatCutCostIsMeasured_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_MeatCutCostIsMeasured
{
    FMars_AutoTest_CuttingStation_MeatCutCostIsMeasured_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_MeatCutCostIsMeasured_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_SweepHandsPiecesToTheTray_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_SweepHandsPiecesToTheTray
{
    FMars_AutoTest_CuttingStation_SweepHandsPiecesToTheTray_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_SweepHandsPiecesToTheTray_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_SweepingTheBoardEmptyTakesTheNextJoint_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_SweepingTheBoardEmptyTakesTheNextJoint
{
    FMars_AutoTest_CuttingStation_SweepingTheBoardEmptyTakesTheNextJoint_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_SweepingTheBoardEmptyTakesTheNextJoint_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_SweepLeavesWhatTheTrayCannotTake_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_SweepLeavesWhatTheTrayCannotTake
{
    FMars_AutoTest_CuttingStation_SweepLeavesWhatTheTrayCannotTake_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_SweepLeavesWhatTheTrayCannotTake_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused
{
    FMars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_TheCleaverFollowsTheChopSignals_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_TheCleaverFollowsTheChopSignals
{
    FMars_AutoTest_CuttingStation_TheCleaverFollowsTheChopSignals_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_TheCleaverFollowsTheChopSignals_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_CuttingStation_TurnYawsTheBoardsPiecesAboutThePile_SpawnParams
{
}

namespace UMars_AutoTest_CuttingStation_TurnYawsTheBoardsPiecesAboutThePile
{
    FMars_AutoTest_CuttingStation_TurnYawsTheBoardsPiecesAboutThePile_SpawnParams Params()
    {
        return FMars_AutoTest_CuttingStation_TurnYawsTheBoardsPiecesAboutThePile_SpawnParams();
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
struct FMars_AutoTest_DamageDealer_SweepIgnoresOwnHurtboxes_SpawnParams
{
}

namespace UMars_AutoTest_DamageDealer_SweepIgnoresOwnHurtboxes
{
    FMars_AutoTest_DamageDealer_SweepIgnoresOwnHurtboxes_SpawnParams Params()
    {
        return FMars_AutoTest_DamageDealer_SweepIgnoresOwnHurtboxes_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Emote_TagsMapToEveryEmoteAndBack_SpawnParams
{
}

namespace UMars_AutoTest_Emote_TagsMapToEveryEmoteAndBack
{
    FMars_AutoTest_Emote_TagsMapToEveryEmoteAndBack_SpawnParams Params()
    {
        return FMars_AutoTest_Emote_TagsMapToEveryEmoteAndBack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Emote_WheelEntryNChoosesEmoteN_SpawnParams
{
}

namespace UMars_AutoTest_Emote_WheelEntryNChoosesEmoteN
{
    FMars_AutoTest_Emote_WheelEntryNChoosesEmoteN_SpawnParams Params()
    {
        return FMars_AutoTest_Emote_WheelEntryNChoosesEmoteN_SpawnParams();
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
struct FMars_AutoTest_Eyes_ApplyWritesComponentPlate_SpawnParams
{
}

namespace UMars_AutoTest_Eyes_ApplyWritesComponentPlate
{
    FMars_AutoTest_Eyes_ApplyWritesComponentPlate_SpawnParams Params()
    {
        return FMars_AutoTest_Eyes_ApplyWritesComponentPlate_SpawnParams();
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
struct FMars_AutoTest_FoodBoard_AChopAfterAWaitingTurnWaitsForIt_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_AChopAfterAWaitingTurnWaitsForIt
{
    FMars_AutoTest_FoodBoard_AChopAfterAWaitingTurnWaitsForIt_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_AChopAfterAWaitingTurnWaitsForIt_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_CutReplacesHeldAndSeparatesHalves_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_CutReplacesHeldAndSeparatesHalves
{
    FMars_AutoTest_FoodBoard_CutReplacesHeldAndSeparatesHalves_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_CutReplacesHeldAndSeparatesHalves_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_CutTargetsOnlyStraddlingPiecesWithinBudget_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_CutTargetsOnlyStraddlingPiecesWithinBudget
{
    FMars_AutoTest_FoodBoard_CutTargetsOnlyStraddlingPiecesWithinBudget_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_CutTargetsOnlyStraddlingPiecesWithinBudget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_DestroyingBoardDestroysHeldOnly_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_DestroyingBoardDestroysHeldOnly
{
    FMars_AutoTest_FoodBoard_DestroyingBoardDestroysHeldOnly_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_DestroyingBoardDestroysHeldOnly_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_DrainsTheInboxAsPlace_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_DrainsTheInboxAsPlace
{
    FMars_AutoTest_FoodBoard_DrainsTheInboxAsPlace_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_DrainsTheInboxAsPlace_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_FullBoardOnlyKnocks_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_FullBoardOnlyKnocks
{
    FMars_AutoTest_FoodBoard_FullBoardOnlyKnocks_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_FullBoardOnlyKnocks_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_HandoffReleaseLeavesNoBodyAndStopsAtMaxPieces_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_HandoffReleaseLeavesNoBodyAndStopsAtMaxPieces
{
    FMars_AutoTest_FoodBoard_HandoffReleaseLeavesNoBodyAndStopsAtMaxPieces_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_HandoffReleaseLeavesNoBodyAndStopsAtMaxPieces_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_KinematicBodiedJointIsPlacedAndCut_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_KinematicBodiedJointIsPlacedAndCut
{
    FMars_AutoTest_FoodBoard_KinematicBodiedJointIsPlacedAndCut_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_KinematicBodiedJointIsPlacedAndCut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_PartingKeepsEveryGap_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_PartingKeepsEveryGap
{
    FMars_AutoTest_FoodBoard_PartingKeepsEveryGap_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_PartingKeepsEveryGap_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_PlaceRefusesPastLimitDuplicateAndForeign_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_PlaceRefusesPastLimitDuplicateAndForeign
{
    FMars_AutoTest_FoodBoard_PlaceRefusesPastLimitDuplicateAndForeign_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_PlaceRefusesPastLimitDuplicateAndForeign_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_RotatedPieceCutsThroughItsCentre_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_RotatedPieceCutsThroughItsCentre
{
    FMars_AutoTest_FoodBoard_RotatedPieceCutsThroughItsCentre_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_RotatedPieceCutsThroughItsCentre_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_SpecValidateRejectsInvalid_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_SpecValidateRejectsInvalid
{
    FMars_AutoTest_FoodBoard_SpecValidateRejectsInvalid_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_SpecValidateRejectsInvalid_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_TurnWaitsForTheInFlightCut_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_TurnWaitsForTheInFlightCut
{
    FMars_AutoTest_FoodBoard_TurnWaitsForTheInFlightCut_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_TurnWaitsForTheInFlightCut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodBoard_TwoTurnsInOneDrainCompose_SpawnParams
{
}

namespace UMars_AutoTest_FoodBoard_TwoTurnsInOneDrainCompose
{
    FMars_AutoTest_FoodBoard_TwoTurnsInOneDrainCompose_SpawnParams Params()
    {
        return FMars_AutoTest_FoodBoard_TwoTurnsInOneDrainCompose_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodDef_EveryMeatFoodReadsTheCookState_SpawnParams
{
}

namespace UMars_AutoTest_FoodDef_EveryMeatFoodReadsTheCookState
{
    FMars_AutoTest_FoodDef_EveryMeatFoodReadsTheCookState_SpawnParams Params()
    {
        return FMars_AutoTest_FoodDef_EveryMeatFoodReadsTheCookState_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_ABatteredPieceWearsItsShellWithTheLedgersLook_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_ABatteredPieceWearsItsShellWithTheLedgersLook
{
    FMars_AutoTest_FoodPiece_ABatteredPieceWearsItsShellWithTheLedgersLook_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_ABatteredPieceWearsItsShellWithTheLedgersLook_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_ABatteredVariantIsOptionalAndValidated_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_ABatteredVariantIsOptionalAndValidated
{
    FMars_AutoTest_FoodPiece_ABatteredVariantIsOptionalAndValidated_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_ABatteredVariantIsOptionalAndValidated_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_ADisplayStartsFromTheLedgersCookState_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_ADisplayStartsFromTheLedgersCookState
{
    FMars_AutoTest_FoodPiece_ADisplayStartsFromTheLedgersCookState_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_ADisplayStartsFromTheLedgersCookState_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_APrepFoodImportsReadyAndCuts_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_APrepFoodImportsReadyAndCuts
{
    FMars_AutoTest_FoodPiece_APrepFoodImportsReadyAndCuts_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_APrepFoodImportsReadyAndCuts_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_BatteredSurvivesACut_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_BatteredSurvivesACut
{
    FMars_AutoTest_FoodPiece_BatteredSurvivesACut_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_BatteredSurvivesACut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_CentreCutConservesMassAndLineage_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_CentreCutConservesMassAndLineage
{
    FMars_AutoTest_FoodPiece_CentreCutConservesMassAndLineage_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_CentreCutConservesMassAndLineage_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_FailedImportIsReported_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_FailedImportIsReported
{
    FMars_AutoTest_FoodPiece_FailedImportIsReported_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_FailedImportIsReported_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_FullQueueRejectsWithoutRetry_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_FullQueueRejectsWithoutRetry
{
    FMars_AutoTest_FoodPiece_FullQueueRejectsWithoutRetry_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_FullQueueRejectsWithoutRetry_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_GrazeIsTouchingOnly_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_GrazeIsTouchingOnly
{
    FMars_AutoTest_FoodPiece_GrazeIsTouchingOnly_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_GrazeIsTouchingOnly_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_HalvesSurviveGarbageCollectionAndRecut_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_HalvesSurviveGarbageCollectionAndRecut
{
    FMars_AutoTest_FoodPiece_HalvesSurviveGarbageCollectionAndRecut_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_HalvesSurviveGarbageCollectionAndRecut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_ImportReadyRecordsVolume_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_ImportReadyRecordsVolume
{
    FMars_AutoTest_FoodPiece_ImportReadyRecordsVolume_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_ImportReadyRecordsVolume_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_KindAndDefinitionFollowTheCut_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_KindAndDefinitionFollowTheCut
{
    FMars_AutoTest_FoodPiece_KindAndDefinitionFollowTheCut_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_KindAndDefinitionFollowTheCut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_MeatSlabCutsIntoConservedPortions_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_MeatSlabCutsIntoConservedPortions
{
    FMars_AutoTest_FoodPiece_MeatSlabCutsIntoConservedPortions_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_MeatSlabCutsIntoConservedPortions_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_MissLeavesSourceUsable_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_MissLeavesSourceUsable
{
    FMars_AutoTest_FoodPiece_MissLeavesSourceUsable_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_MissLeavesSourceUsable_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_OffCentreCutIsProportionalToVolume_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_OffCentreCutIsProportionalToVolume
{
    FMars_AutoTest_FoodPiece_OffCentreCutIsProportionalToVolume_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_OffCentreCutIsProportionalToVolume_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_OneHolderPerPiece_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_OneHolderPerPiece
{
    FMars_AutoTest_FoodPiece_OneHolderPerPiece_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_OneHolderPerPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_SecondCutWhileCuttingIsRefusedBusy_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_SecondCutWhileCuttingIsRefusedBusy
{
    FMars_AutoTest_FoodPiece_SecondCutWhileCuttingIsRefusedBusy_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_SecondCutWhileCuttingIsRefusedBusy_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_SetCookStateAppliesBeforeACutInTheSameDrain_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_SetCookStateAppliesBeforeACutInTheSameDrain
{
    FMars_AutoTest_FoodPiece_SetCookStateAppliesBeforeACutInTheSameDrain_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_SetCookStateAppliesBeforeACutInTheSameDrain_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_SourceDestroyedWhilePendingCommitsNothing_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_SourceDestroyedWhilePendingCommitsNothing
{
    FMars_AutoTest_FoodPiece_SourceDestroyedWhilePendingCommitsNothing_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_SourceDestroyedWhilePendingCommitsNothing_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_SpecValidateRejectsInvalid_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_SpecValidateRejectsInvalid
{
    FMars_AutoTest_FoodPiece_SpecValidateRejectsInvalid_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_SpecValidateRejectsInvalid_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FoodPiece_TooSmallPortionIsRejected_SpawnParams
{
}

namespace UMars_AutoTest_FoodPiece_TooSmallPortionIsRejected
{
    FMars_AutoTest_FoodPiece_TooSmallPortionIsRejected_SpawnParams Params()
    {
        return FMars_AutoTest_FoodPiece_TooSmallPortionIsRejected_SpawnParams();
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
struct FMars_AutoTest_FPHands_AHoldWhoseTargetDiesReleases_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_AHoldWhoseTargetDiesReleases
{
    FMars_AutoTest_FPHands_AHoldWhoseTargetDiesReleases_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_AHoldWhoseTargetDiesReleases_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_APlaceReachCarriesATwoHandedHoldToTheTarget_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_APlaceReachCarriesATwoHandedHoldToTheTarget
{
    FMars_AutoTest_FPHands_APlaceReachCarriesATwoHandedHoldToTheTarget_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_APlaceReachCarriesATwoHandedHoldToTheTarget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_ARefusedReachSaysWhy_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_ARefusedReachSaysWhy
{
    FMars_AutoTest_FPHands_ARefusedReachSaysWhy_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_ARefusedReachSaysWhy_SpawnParams();
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
struct FMars_AutoTest_FPHands_GripRotationPutsTheIndexSideWhereTheHandSays_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_GripRotationPutsTheIndexSideWhereTheHandSays
{
    FMars_AutoTest_FPHands_GripRotationPutsTheIndexSideWhereTheHandSays_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_GripRotationPutsTheIndexSideWhereTheHandSays_SpawnParams();
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
struct FMars_AutoTest_FPHands_LookingUpLeavesTheGlovesLow_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_LookingUpLeavesTheGlovesLow
{
    FMars_AutoTest_FPHands_LookingUpLeavesTheGlovesLow_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_LookingUpLeavesTheGlovesLow_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_PitchSpecRejectsFollowOutsideZeroToOne_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_PitchSpecRejectsFollowOutsideZeroToOne
{
    FMars_AutoTest_FPHands_PitchSpecRejectsFollowOutsideZeroToOne_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_PitchSpecRejectsFollowOutsideZeroToOne_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FPHands_PoseOverrideAppliesOnlyWhileReaching_SpawnParams
{
}

namespace UMars_AutoTest_FPHands_PoseOverrideAppliesOnlyWhileReaching
{
    FMars_AutoTest_FPHands_PoseOverrideAppliesOnlyWhileReaching_SpawnParams Params()
    {
        return FMars_AutoTest_FPHands_PoseOverrideAppliesOnlyWhileReaching_SpawnParams();
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
struct FMars_AutoTest_Fry_ABatteredWholePieceFriesGolden_SpawnParams
{
}

namespace UMars_AutoTest_Fry_ABatteredWholePieceFriesGolden
{
    FMars_AutoTest_Fry_ABatteredWholePieceFriesGolden_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_ABatteredWholePieceFriesGolden_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_ADippedScoopCannotLeaveThePot_SpawnParams
{
}

namespace UMars_AutoTest_Fry_ADippedScoopCannotLeaveThePot
{
    FMars_AutoTest_Fry_ADippedScoopCannotLeaveThePot_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_ADippedScoopCannotLeaveThePot_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_AdmissionRefusesAnUnbatteredPiece_SpawnParams
{
}

namespace UMars_AutoTest_Fry_AdmissionRefusesAnUnbatteredPiece
{
    FMars_AutoTest_Fry_AdmissionRefusesAnUnbatteredPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_AdmissionRefusesAnUnbatteredPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_AdmissionRejectsASeventhPiece_SpawnParams
{
}

namespace UMars_AutoTest_Fry_AdmissionRejectsASeventhPiece
{
    FMars_AutoTest_Fry_AdmissionRejectsASeventhPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_AdmissionRejectsASeventhPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart_SpawnParams
{
}

namespace UMars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart
{
    FMars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_ADrainedPieceKnockedOutIsNoLongerDrained_SpawnParams
{
}

namespace UMars_AutoTest_Fry_ADrainedPieceKnockedOutIsNoLongerDrained
{
    FMars_AutoTest_Fry_ADrainedPieceKnockedOutIsNoLongerDrained_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_ADrainedPieceKnockedOutIsNoLongerDrained_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain_SpawnParams
{
}

namespace UMars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain
{
    FMars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_APieceOnAnotherPieceDrains_SpawnParams
{
}

namespace UMars_AutoTest_Fry_APieceOnAnotherPieceDrains
{
    FMars_AutoTest_Fry_APieceOnAnotherPieceDrains_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_APieceOnAnotherPieceDrains_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_APieceThatNeverStillsDrainsAtTheBudget_SpawnParams
{
}

namespace UMars_AutoTest_Fry_APieceThatNeverStillsDrainsAtTheBudget
{
    FMars_AutoTest_Fry_APieceThatNeverStillsDrainsAtTheBudget_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_APieceThatNeverStillsDrainsAtTheBudget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_APourInTheCorridorIsIgnored_SpawnParams
{
}

namespace UMars_AutoTest_Fry_APourInTheCorridorIsIgnored
{
    FMars_AutoTest_Fry_APourInTheCorridorIsIgnored_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_APourInTheCorridorIsIgnored_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_AResetRejectsAnAddPieceInTheSameDrain_SpawnParams
{
}

namespace UMars_AutoTest_Fry_AResetRejectsAnAddPieceInTheSameDrain
{
    FMars_AutoTest_Fry_AResetRejectsAnAddPieceInTheSameDrain_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_AResetRejectsAnAddPieceInTheSameDrain_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection_SpawnParams
{
}

namespace UMars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection
{
    FMars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_ASearedPieceRetargetsItsResting_SpawnParams
{
}

namespace UMars_AutoTest_Fry_ASearedPieceRetargetsItsResting
{
    FMars_AutoTest_Fry_ASearedPieceRetargetsItsResting_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_ASearedPieceRetargetsItsResting_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_DrainsTheInboxAsAddPiece_SpawnParams
{
}

namespace UMars_AutoTest_Fry_DrainsTheInboxAsAddPiece
{
    FMars_AutoTest_Fry_DrainsTheInboxAsAddPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_DrainsTheInboxAsAddPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine_SpawnParams
{
}

namespace UMars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine
{
    FMars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains_SpawnParams
{
}

namespace UMars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains
{
    FMars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_SpecValidateRejectsBadSpecs_SpawnParams
{
}

namespace UMars_AutoTest_Fry_SpecValidateRejectsBadSpecs
{
    FMars_AutoTest_Fry_SpecValidateRejectsBadSpecs_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_SpecValidateRejectsBadSpecs_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_TakeOutWritesOilCoat_SpawnParams
{
}

namespace UMars_AutoTest_Fry_TakeOutWritesOilCoat
{
    FMars_AutoTest_Fry_TakeOutWritesOilCoat_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_TakeOutWritesOilCoat_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Fry_WhereaboutsFollowTheGeometry_SpawnParams
{
}

namespace UMars_AutoTest_Fry_WhereaboutsFollowTheGeometry
{
    FMars_AutoTest_Fry_WhereaboutsFollowTheGeometry_SpawnParams Params()
    {
        return FMars_AutoTest_Fry_WhereaboutsFollowTheGeometry_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FryStation_APlatterSourcedPieceDrainsAndIsTakenOut_SpawnParams
{
}

namespace UMars_AutoTest_FryStation_APlatterSourcedPieceDrainsAndIsTakenOut
{
    FMars_AutoTest_FryStation_APlatterSourcedPieceDrainsAndIsTakenOut_SpawnParams Params()
    {
        return FMars_AutoTest_FryStation_APlatterSourcedPieceDrainsAndIsTakenOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FryStation_ARefusedTakeOutSaysTrayFull_SpawnParams
{
}

namespace UMars_AutoTest_FryStation_ARefusedTakeOutSaysTrayFull
{
    FMars_AutoTest_FryStation_ARefusedTakeOutSaysTrayFull_SpawnParams Params()
    {
        return FMars_AutoTest_FryStation_ARefusedTakeOutSaysTrayFull_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FryStation_ATakeOutRefusedByTheTrayIsReadopted_SpawnParams
{
}

namespace UMars_AutoTest_FryStation_ATakeOutRefusedByTheTrayIsReadopted
{
    FMars_AutoTest_FryStation_ATakeOutRefusedByTheTrayIsReadopted_SpawnParams Params()
    {
        return FMars_AutoTest_FryStation_ATakeOutRefusedByTheTrayIsReadopted_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray_SpawnParams
{
}

namespace UMars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray
{
    FMars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray_SpawnParams Params()
    {
        return FMars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FryStation_BatterHeatReachesThePieceDisplay_SpawnParams
{
}

namespace UMars_AutoTest_FryStation_BatterHeatReachesThePieceDisplay
{
    FMars_AutoTest_FryStation_BatterHeatReachesThePieceDisplay_SpawnParams Params()
    {
        return FMars_AutoTest_FryStation_BatterHeatReachesThePieceDisplay_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FryStation_LeavingDuringCarryStillAdmits_SpawnParams
{
}

namespace UMars_AutoTest_FryStation_LeavingDuringCarryStillAdmits
{
    FMars_AutoTest_FryStation_LeavingDuringCarryStillAdmits_SpawnParams Params()
    {
        return FMars_AutoTest_FryStation_LeavingDuringCarryStillAdmits_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_FryStation_TakeOutLoadsTheTray_SpawnParams
{
}

namespace UMars_AutoTest_FryStation_TakeOutLoadsTheTray
{
    FMars_AutoTest_FryStation_TakeOutLoadsTheTray_SpawnParams Params()
    {
        return FMars_AutoTest_FryStation_TakeOutLoadsTheTray_SpawnParams();
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
struct FMars_AutoTest_HandSwing_CancelRecoversFromTheCurrentPose_SpawnParams
{
}

namespace UMars_AutoTest_HandSwing_CancelRecoversFromTheCurrentPose
{
    FMars_AutoTest_HandSwing_CancelRecoversFromTheCurrentPose_SpawnParams Params()
    {
        return FMars_AutoTest_HandSwing_CancelRecoversFromTheCurrentPose_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_HandSwing_StartRequestValidates_SpawnParams
{
}

namespace UMars_AutoTest_HandSwing_StartRequestValidates
{
    FMars_AutoTest_HandSwing_StartRequestValidates_SpawnParams Params()
    {
        return FMars_AutoTest_HandSwing_StartRequestValidates_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_HandSwing_StartRunsWindupStrikeRecoverToNone_SpawnParams
{
}

namespace UMars_AutoTest_HandSwing_StartRunsWindupStrikeRecoverToNone
{
    FMars_AutoTest_HandSwing_StartRunsWindupStrikeRecoverToNone_SpawnParams Params()
    {
        return FMars_AutoTest_HandSwing_StartRunsWindupStrikeRecoverToNone_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_HangingChain_CatenaryLaysLinksAndSags_SpawnParams
{
}

namespace UMars_AutoTest_HangingChain_CatenaryLaysLinksAndSags
{
    FMars_AutoTest_HangingChain_CatenaryLaysLinksAndSags_SpawnParams Params()
    {
        return FMars_AutoTest_HangingChain_CatenaryLaysLinksAndSags_SpawnParams();
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
struct FMars_AutoTest_HeldItem_SyncsFromTheHotbarWithoutATask_SpawnParams
{
}

namespace UMars_AutoTest_HeldItem_SyncsFromTheHotbarWithoutATask
{
    FMars_AutoTest_HeldItem_SyncsFromTheHotbarWithoutATask_SpawnParams Params()
    {
        return FMars_AutoTest_HeldItem_SyncsFromTheHotbarWithoutATask_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_HeldView_ItemSitsAtTheRightPalm_SpawnParams
{
}

namespace UMars_AutoTest_HeldView_ItemSitsAtTheRightPalm
{
    FMars_AutoTest_HeldView_ItemSitsAtTheRightPalm_SpawnParams Params()
    {
        return FMars_AutoTest_HeldView_ItemSitsAtTheRightPalm_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_HeldView_MakeMatchesFPHold_SpawnParams
{
}

namespace UMars_AutoTest_HeldView_MakeMatchesFPHold
{
    FMars_AutoTest_HeldView_MakeMatchesFPHold_SpawnParams Params()
    {
        return FMars_AutoTest_HeldView_MakeMatchesFPHold_SpawnParams();
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
struct FMars_AutoTest_HitZone_HurtboxRegistration_SpawnParams
{
}

namespace UMars_AutoTest_HitZone_HurtboxRegistration
{
    FMars_AutoTest_HitZone_HurtboxRegistration_SpawnParams Params()
    {
        return FMars_AutoTest_HitZone_HurtboxRegistration_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_AStowWhileHoldingKeepsTheSelection_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_AStowWhileHoldingKeepsTheSelection
{
    FMars_AutoTest_Hotbar_AStowWhileHoldingKeepsTheSelection_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_AStowWhileHoldingKeepsTheSelection_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Hotbar_AStowWithNoSelectionSelectsTheSlot_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_AStowWithNoSelectionSelectsTheSlot
{
    FMars_AutoTest_Hotbar_AStowWithNoSelectionSelectsTheSlot_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_AStowWithNoSelectionSelectsTheSlot_SpawnParams();
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
struct FMars_AutoTest_Hotbar_HandsOnlyItemStowsOnlyToTheOverflow_SpawnParams
{
}

namespace UMars_AutoTest_Hotbar_HandsOnlyItemStowsOnlyToTheOverflow
{
    FMars_AutoTest_Hotbar_HandsOnlyItemStowsOnlyToTheOverflow_SpawnParams Params()
    {
        return FMars_AutoTest_Hotbar_HandsOnlyItemStowsOnlyToTheOverflow_SpawnParams();
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
struct FMars_AutoTest_Implement_ACommandedSlideIgnoresTheLookAndTracksItsTarget_SpawnParams
{
}

namespace UMars_AutoTest_Implement_ACommandedSlideIgnoresTheLookAndTracksItsTarget
{
    FMars_AutoTest_Implement_ACommandedSlideIgnoresTheLookAndTracksItsTarget_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_ACommandedSlideIgnoresTheLookAndTracksItsTarget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Implement_ATiltTargetCanBeSetWithoutALook_SpawnParams
{
}

namespace UMars_AutoTest_Implement_ATiltTargetCanBeSetWithoutALook
{
    FMars_AutoTest_Implement_ATiltTargetCanBeSetWithoutALook_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_ATiltTargetCanBeSetWithoutALook_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Implement_CommandedLiftFollowsTheLookAndHolds_SpawnParams
{
}

namespace UMars_AutoTest_Implement_CommandedLiftFollowsTheLookAndHolds
{
    FMars_AutoTest_Implement_CommandedLiftFollowsTheLookAndHolds_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_CommandedLiftFollowsTheLookAndHolds_SpawnParams();
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
struct FMars_AutoTest_Implement_PitchAndYawHoldsWhileDrivenAndParksWhenIdle_SpawnParams
{
}

namespace UMars_AutoTest_Implement_PitchAndYawHoldsWhileDrivenAndParksWhenIdle
{
    FMars_AutoTest_Implement_PitchAndYawHoldsWhileDrivenAndParksWhenIdle_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_PitchAndYawHoldsWhileDrivenAndParksWhenIdle_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Implement_SlideFollowsTheLookAndALiftTargetCanBeSet_SpawnParams
{
}

namespace UMars_AutoTest_Implement_SlideFollowsTheLookAndALiftTargetCanBeSet
{
    FMars_AutoTest_Implement_SlideFollowsTheLookAndALiftTargetCanBeSet_SpawnParams Params()
    {
        return FMars_AutoTest_Implement_SlideFollowsTheLookAndALiftTargetCanBeSet_SpawnParams();
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
struct FMars_AutoTest_Interactable_ACancelledInteractionStopsTheSubSm_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_ACancelledInteractionStopsTheSubSm
{
    FMars_AutoTest_Interactable_ACancelledInteractionStopsTheSubSm_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_ACancelledInteractionStopsTheSubSm_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_AClaimIsHeldUntilEveryReasonIsReleased_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_AClaimIsHeldUntilEveryReasonIsReleased
{
    FMars_AutoTest_Interactable_AClaimIsHeldUntilEveryReasonIsReleased_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_AClaimIsHeldUntilEveryReasonIsReleased_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_ADisabledInteractableLosesFocusAndItsTargets_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_ADisabledInteractableLosesFocusAndItsTargets
{
    FMars_AutoTest_Interactable_ADisabledInteractableLosesFocusAndItsTargets_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_ADisabledInteractableLosesFocusAndItsTargets_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_AFocusKeepingClaimDisablesTheTargetsAndKeepsThePrompt_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_AFocusKeepingClaimDisablesTheTargetsAndKeepsThePrompt
{
    FMars_AutoTest_Interactable_AFocusKeepingClaimDisablesTheTargetsAndKeepsThePrompt_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_AFocusKeepingClaimDisablesTheTargetsAndKeepsThePrompt_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_AGripTaskPastAcceptanceSurvivesACancel_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_AGripTaskPastAcceptanceSurvivesACancel
{
    FMars_AutoTest_Interactable_AGripTaskPastAcceptanceSurvivesACancel_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_AGripTaskPastAcceptanceSurvivesACancel_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_AGripTaskTornDownMidWaitMovesNothing_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_AGripTaskTornDownMidWaitMovesNothing
{
    FMars_AutoTest_Interactable_AGripTaskTornDownMidWaitMovesNothing_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_AGripTaskTornDownMidWaitMovesNothing_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_AMarsDisableDisablesTheFrameworkTarget_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_AMarsDisableDisablesTheFrameworkTarget
{
    FMars_AutoTest_Interactable_AMarsDisableDisablesTheFrameworkTarget_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_AMarsDisableDisablesTheFrameworkTarget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_AWhileLiveTargetTakesOneInteractionAtATime_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_AWhileLiveTargetTakesOneInteractionAtATime
{
    FMars_AutoTest_Interactable_AWhileLiveTargetTakesOneInteractionAtATime_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_AWhileLiveTargetTakesOneInteractionAtATime_SpawnParams();
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
struct FMars_AutoTest_Interactable_InteractingEntersFromIdleOnALiveInteraction_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_InteractingEntersFromIdleOnALiveInteraction
{
    FMars_AutoTest_Interactable_InteractingEntersFromIdleOnALiveInteraction_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_InteractingEntersFromIdleOnALiveInteraction_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Interactable_TheInitiatorComesFromTheLiveInteraction_SpawnParams
{
}

namespace UMars_AutoTest_Interactable_TheInitiatorComesFromTheLiveInteraction
{
    FMars_AutoTest_Interactable_TheInitiatorComesFromTheLiveInteraction_SpawnParams Params()
    {
        return FMars_AutoTest_Interactable_TheInitiatorComesFromTheLiveInteraction_SpawnParams();
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
struct FMars_AutoTest_Platter_ADepartureResettlesOnlyWhatItSupported_SpawnParams
{
}

namespace UMars_AutoTest_Platter_ADepartureResettlesOnlyWhatItSupported
{
    FMars_AutoTest_Platter_ADepartureResettlesOnlyWhatItSupported_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_ADepartureResettlesOnlyWhatItSupported_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_ADepositWhoseReleaseIsRefusedKeepsTheFood_SpawnParams
{
}

namespace UMars_AutoTest_Platter_ADepositWhoseReleaseIsRefusedKeepsTheFood
{
    FMars_AutoTest_Platter_ADepositWhoseReleaseIsRefusedKeepsTheFood_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_ADepositWhoseReleaseIsRefusedKeepsTheFood_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_ADroppedPieceSettlesFreezesAndRidesTheTray_SpawnParams
{
}

namespace UMars_AutoTest_Platter_ADroppedPieceSettlesFreezesAndRidesTheTray
{
    FMars_AutoTest_Platter_ADroppedPieceSettlesFreezesAndRidesTheTray_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_ADroppedPieceSettlesFreezesAndRidesTheTray_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AFoodTakenByTheGlovesWhileSettlingIsNotPulledBack_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AFoodTakenByTheGlovesWhileSettlingIsNotPulledBack
{
    FMars_AutoTest_Platter_AFoodTakenByTheGlovesWhileSettlingIsNotPulledBack_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AFoodTakenByTheGlovesWhileSettlingIsNotPulledBack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack
{
    FMars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AGripTaskThatFailsRecordsItsReason_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AGripTaskThatFailsRecordsItsReason
{
    FMars_AutoTest_Platter_AGripTaskThatFailsRecordsItsReason_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AGripTaskThatFailsRecordsItsReason_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AMountedPlattersPiecesIgnorePawns_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AMountedPlattersPiecesIgnorePawns
{
    FMars_AutoTest_Platter_AMountedPlattersPiecesIgnorePawns_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AMountedPlattersPiecesIgnorePawns_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AMovingTrayDropsNothing_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AMovingTrayDropsNothing
{
    FMars_AutoTest_Platter_AMovingTrayDropsNothing_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AMovingTrayDropsNothing_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AnEscapeWhileTheTrayMovesWaitsForStillness_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AnEscapeWhileTheTrayMovesWaitsForStillness
{
    FMars_AutoTest_Platter_AnEscapeWhileTheTrayMovesWaitsForStillness_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AnEscapeWhileTheTrayMovesWaitsForStillness_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_APieceWhoseBodyFailsSetupIsRefusedNotStranded_SpawnParams
{
}

namespace UMars_AutoTest_Platter_APieceWhoseBodyFailsSetupIsRefusedNotStranded
{
    FMars_AutoTest_Platter_APieceWhoseBodyFailsSetupIsRefusedNotStranded_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_APieceWhoseBodyFailsSetupIsRefusedNotStranded_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AQueuedFoodTakenByHandIsNotPulledBack_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AQueuedFoodTakenByHandIsNotPulledBack
{
    FMars_AutoTest_Platter_AQueuedFoodTakenByHandIsNotPulledBack_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AQueuedFoodTakenByHandIsNotPulledBack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_AStillMovingPieceFreezesAtMaxSeconds_SpawnParams
{
}

namespace UMars_AutoTest_Platter_AStillMovingPieceFreezesAtMaxSeconds
{
    FMars_AutoTest_Platter_AStillMovingPieceFreezesAtMaxSeconds_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_AStillMovingPieceFreezesAtMaxSeconds_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_DepositIsBlockedWhenFull_SpawnParams
{
}

namespace UMars_AutoTest_Platter_DepositIsBlockedWhenFull
{
    FMars_AutoTest_Platter_DepositIsBlockedWhenFull_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_DepositIsBlockedWhenFull_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_DepositPlacesTheHeldFoodAndPickupTakesItBack_SpawnParams
{
}

namespace UMars_AutoTest_Platter_DepositPlacesTheHeldFoodAndPickupTakesItBack
{
    FMars_AutoTest_Platter_DepositPlacesTheHeldFoodAndPickupTakesItBack_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_DepositPlacesTheHeldFoodAndPickupTakesItBack_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_DestroyingAPlatterEndsItsPieces_SpawnParams
{
}

namespace UMars_AutoTest_Platter_DestroyingAPlatterEndsItsPieces
{
    FMars_AutoTest_Platter_DestroyingAPlatterEndsItsPieces_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_DestroyingAPlatterEndsItsPieces_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_FullRefusesTheNext_SpawnParams
{
}

namespace UMars_AutoTest_Platter_FullRefusesTheNext
{
    FMars_AutoTest_Platter_FullRefusesTheNext_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_FullRefusesTheNext_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_LoadedBodyGoesKinematicAndRides_SpawnParams
{
}

namespace UMars_AutoTest_Platter_LoadedBodyGoesKinematicAndRides
{
    FMars_AutoTest_Platter_LoadedBodyGoesKinematicAndRides_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_LoadedBodyGoesKinematicAndRides_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_LoadRefusesADuplicate_SpawnParams
{
}

namespace UMars_AutoTest_Platter_LoadRefusesADuplicate
{
    FMars_AutoTest_Platter_LoadRefusesADuplicate_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_LoadRefusesADuplicate_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_LoadRefusesAForeignPiece_SpawnParams
{
}

namespace UMars_AutoTest_Platter_LoadRefusesAForeignPiece
{
    FMars_AutoTest_Platter_LoadRefusesAForeignPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_LoadRefusesAForeignPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_LoadRefusesAFullPlatter_SpawnParams
{
}

namespace UMars_AutoTest_Platter_LoadRefusesAFullPlatter
{
    FMars_AutoTest_Platter_LoadRefusesAFullPlatter_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_LoadRefusesAFullPlatter_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_LoadRefusesAPieceBeingCut_SpawnParams
{
}

namespace UMars_AutoTest_Platter_LoadRefusesAPieceBeingCut
{
    FMars_AutoTest_Platter_LoadRefusesAPieceBeingCut_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_LoadRefusesAPieceBeingCut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_ReconcileDropsAPieceTakenByHand_SpawnParams
{
}

namespace UMars_AutoTest_Platter_ReconcileDropsAPieceTakenByHand
{
    FMars_AutoTest_Platter_ReconcileDropsAPieceTakenByHand_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_ReconcileDropsAPieceTakenByHand_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint_SpawnParams
{
}

namespace UMars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint
{
    FMars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_TwoUnloadsOfOnePieceInOneDrainAreOne_SpawnParams
{
}

namespace UMars_AutoTest_Platter_TwoUnloadsOfOnePieceInOneDrainAreOne
{
    FMars_AutoTest_Platter_TwoUnloadsOfOnePieceInOneDrainAreOne_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_TwoUnloadsOfOnePieceInOneDrainAreOne_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_UnloadKeepsTheWorldPoseAndReloadsAfterAMove_SpawnParams
{
}

namespace UMars_AutoTest_Platter_UnloadKeepsTheWorldPoseAndReloadsAfterAMove
{
    FMars_AutoTest_Platter_UnloadKeepsTheWorldPoseAndReloadsAfterAMove_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_UnloadKeepsTheWorldPoseAndReloadsAfterAMove_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_UnloadResettlesTheRest_SpawnParams
{
}

namespace UMars_AutoTest_Platter_UnloadResettlesTheRest
{
    FMars_AutoTest_Platter_UnloadResettlesTheRest_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_UnloadResettlesTheRest_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Platter_WorldItemCarriesItsPiecesThroughStowHoldAndRelease_SpawnParams
{
}

namespace UMars_AutoTest_Platter_WorldItemCarriesItsPiecesThroughStowHoldAndRelease
{
    FMars_AutoTest_Platter_WorldItemCarriesItsPiecesThroughStowHoldAndRelease_SpawnParams Params()
    {
        return FMars_AutoTest_Platter_WorldItemCarriesItsPiecesThroughStowHoldAndRelease_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_AnUndockThatFailsFailsTheTake_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_AnUndockThatFailsFailsTheTake
{
    FMars_AutoTest_PlatterDock_AnUndockThatFailsFailsTheTake_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_AnUndockThatFailsFailsTheTake_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_APolicyCountsQueuedAndSettlingPieces_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_APolicyCountsQueuedAndSettlingPieces
{
    FMars_AutoTest_PlatterDock_APolicyCountsQueuedAndSettlingPieces_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_APolicyCountsQueuedAndSettlingPieces_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_ATakeAtTheGripArrivesWithTheGlovesReturn_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_ATakeAtTheGripArrivesWithTheGlovesReturn
{
    FMars_AutoTest_PlatterDock_ATakeAtTheGripArrivesWithTheGlovesReturn_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_ATakeAtTheGripArrivesWithTheGlovesReturn_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival
{
    FMars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_DestroyedDockEndsItsPlatter_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_DestroyedDockEndsItsPlatter
{
    FMars_AutoTest_PlatterDock_DestroyedDockEndsItsPlatter_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_DestroyedDockEndsItsPlatter_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_DockFromTheHandIsOneCarryAndTakeIsOneHold_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_DockFromTheHandIsOneCarryAndTakeIsOneHold
{
    FMars_AutoTest_PlatterDock_DockFromTheHandIsOneCarryAndTakeIsOneHold_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_DockFromTheHandIsOneCarryAndTakeIsOneHold_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_DocksAWorldPlatterAndUndocksIntoTheOverflow_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_DocksAWorldPlatterAndUndocksIntoTheOverflow
{
    FMars_AutoTest_PlatterDock_DocksAWorldPlatterAndUndocksIntoTheOverflow_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_DocksAWorldPlatterAndUndocksIntoTheOverflow_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_OnArrivedFollowsOnMountSettled_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_OnArrivedFollowsOnMountSettled
{
    FMars_AutoTest_PlatterDock_OnArrivedFollowsOnMountSettled_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_OnArrivedFollowsOnMountSettled_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind
{
    FMars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_PlaceFoodLoadsTheDockedPlatter_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_PlaceFoodLoadsTheDockedPlatter
{
    FMars_AutoTest_PlatterDock_PlaceFoodLoadsTheDockedPlatter_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_PlaceFoodLoadsTheDockedPlatter_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_PlaceRunsAPlaceReachAndDocksAtTheGrip_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_PlaceRunsAPlaceReachAndDocksAtTheGrip
{
    FMars_AutoTest_PlatterDock_PlaceRunsAPlaceReachAndDocksAtTheGrip_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_PlaceRunsAPlaceReachAndDocksAtTheGrip_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_PolicyRefusesKindWholeCountAndEmpty_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_PolicyRefusesKindWholeCountAndEmpty
{
    FMars_AutoTest_PlatterDock_PolicyRefusesKindWholeCountAndEmpty_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_PolicyRefusesKindWholeCountAndEmpty_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlatterDock_TakeReachesWithBothGloves_SpawnParams
{
}

namespace UMars_AutoTest_PlatterDock_TakeReachesWithBothGloves
{
    FMars_AutoTest_PlatterDock_TakeReachesWithBothGloves_SpawnParams Params()
    {
        return FMars_AutoTest_PlatterDock_TakeReachesWithBothGloves_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Player_AFocusedLiveInteractionIsPinned_SpawnParams
{
}

namespace UMars_AutoTest_Player_AFocusedLiveInteractionIsPinned
{
    FMars_AutoTest_Player_AFocusedLiveInteractionIsPinned_SpawnParams Params()
    {
        return FMars_AutoTest_Player_AFocusedLiveInteractionIsPinned_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Player_AHeldRowAtEntryIsNotAPress_SpawnParams
{
}

namespace UMars_AutoTest_Player_AHeldRowAtEntryIsNotAPress
{
    FMars_AutoTest_Player_AHeldRowAtEntryIsNotAPress_SpawnParams Params()
    {
        return FMars_AutoTest_Player_AHeldRowAtEntryIsNotAPress_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget_SpawnParams
{
}

namespace UMars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget
{
    FMars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget_SpawnParams Params()
    {
        return FMars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Player_AHeldUseLandsOnAnItemTheViewArrivesAt_SpawnParams
{
}

namespace UMars_AutoTest_Player_AHeldUseLandsOnAnItemTheViewArrivesAt
{
    FMars_AutoTest_Player_AHeldUseLandsOnAnItemTheViewArrivesAt_SpawnParams Params()
    {
        return FMars_AutoTest_Player_AHeldUseLandsOnAnItemTheViewArrivesAt_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Player_APressDuringAPushStillReaches_SpawnParams
{
}

namespace UMars_AutoTest_Player_APressDuringAPushStillReaches
{
    FMars_AutoTest_Player_APressDuringAPushStillReaches_SpawnParams Params()
    {
        return FMars_AutoTest_Player_APressDuringAPushStillReaches_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Player_ASameFramePressAndReleaseStillInteracts_SpawnParams
{
}

namespace UMars_AutoTest_Player_ASameFramePressAndReleaseStillInteracts
{
    FMars_AutoTest_Player_ASameFramePressAndReleaseStillInteracts_SpawnParams Params()
    {
        return FMars_AutoTest_Player_ASameFramePressAndReleaseStillInteracts_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Player_FocusTakesTheNearestHitAndNestedPriorityOnly_SpawnParams
{
}

namespace UMars_AutoTest_Player_FocusTakesTheNearestHitAndNestedPriorityOnly
{
    FMars_AutoTest_Player_FocusTakesTheNearestHitAndNestedPriorityOnly_SpawnParams Params()
    {
        return FMars_AutoTest_Player_FocusTakesTheNearestHitAndNestedPriorityOnly_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_ClimbRace_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_ClimbRace
{
    FMars_AutoTest_PlayerCombat_ClimbRace_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_ClimbRace_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_CrouchAndBlockedUncrouch_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_CrouchAndBlockedUncrouch
{
    FMars_AutoTest_PlayerCombat_CrouchAndBlockedUncrouch_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_CrouchAndBlockedUncrouch_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_DebugAndHeal_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_DebugAndHeal
{
    FMars_AutoTest_PlayerCombat_DebugAndHeal_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_DebugAndHeal_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_LethalDowned_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_LethalDowned
{
    FMars_AutoTest_PlayerCombat_LethalDowned_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_LethalDowned_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_Lifetime_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_Lifetime
{
    FMars_AutoTest_PlayerCombat_Lifetime_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_Lifetime_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_PlayerStrikeSelfExclusion_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_PlayerStrikeSelfExclusion
{
    FMars_AutoTest_PlayerCombat_PlayerStrikeSelfExclusion_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_PlayerStrikeSelfExclusion_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_ProductionReceiver_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_ProductionReceiver
{
    FMars_AutoTest_PlayerCombat_ProductionReceiver_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_ProductionReceiver_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_PlayerCombat_ReceiverWaitsForLocalControl_SpawnParams
{
}

namespace UMars_AutoTest_PlayerCombat_ReceiverWaitsForLocalControl
{
    FMars_AutoTest_PlayerCombat_ReceiverWaitsForLocalControl_SpawnParams Params()
    {
        return FMars_AutoTest_PlayerCombat_ReceiverWaitsForLocalControl_SpawnParams();
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
struct FMars_AutoTest_Resting_RetargetRestsOnTheNewTargetOnly_SpawnParams
{
}

namespace UMars_AutoTest_Resting_RetargetRestsOnTheNewTargetOnly
{
    FMars_AutoTest_Resting_RetargetRestsOnTheNewTargetOnly_SpawnParams Params()
    {
        return FMars_AutoTest_Resting_RetargetRestsOnTheNewTargetOnly_SpawnParams();
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
struct FMars_AutoTest_Resting_TwoTargetsAreToldApart_SpawnParams
{
}

namespace UMars_AutoTest_Resting_TwoTargetsAreToldApart
{
    FMars_AutoTest_Resting_TwoTargetsAreToldApart_SpawnParams Params()
    {
        return FMars_AutoTest_Resting_TwoTargetsAreToldApart_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_ACutSlabHalfSearsEverySideAndIsReady_SpawnParams
{
}

namespace UMars_AutoTest_Searing_ACutSlabHalfSearsEverySideAndIsReady
{
    FMars_AutoTest_Searing_ACutSlabHalfSearsEverySideAndIsReady_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_ACutSlabHalfSearsEverySideAndIsReady_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId_SpawnParams
{
}

namespace UMars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId
{
    FMars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_AdmissionRejectsASeventhPiece_SpawnParams
{
}

namespace UMars_AutoTest_Searing_AdmissionRejectsASeventhPiece
{
    FMars_AutoTest_Searing_AdmissionRejectsASeventhPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_AdmissionRejectsASeventhPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_AdoptsAPieceWithItsOwnExtentsAndSeedsItsSear_SpawnParams
{
}

namespace UMars_AutoTest_Searing_AdoptsAPieceWithItsOwnExtentsAndSeedsItsSear
{
    FMars_AutoTest_Searing_AdoptsAPieceWithItsOwnExtentsAndSeedsItsSear_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_AdoptsAPieceWithItsOwnExtentsAndSeedsItsSear_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_AFriedPieceKeepsItsBatterChannel_SpawnParams
{
}

namespace UMars_AutoTest_Searing_AFriedPieceKeepsItsBatterChannel
{
    FMars_AutoTest_Searing_AFriedPieceKeepsItsBatterChannel_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_AFriedPieceKeepsItsBatterChannel_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_APieceTenCentimetresUnderThePanIsLost_SpawnParams
{
}

namespace UMars_AutoTest_Searing_APieceTenCentimetresUnderThePanIsLost
{
    FMars_AutoTest_Searing_APieceTenCentimetresUnderThePanIsLost_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_APieceTenCentimetresUnderThePanIsLost_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_APieceThatNeverArrivesIsJudgedAfterTheTimeout_SpawnParams
{
}

namespace UMars_AutoTest_Searing_APieceThatNeverArrivesIsJudgedAfterTheTimeout
{
    FMars_AutoTest_Searing_APieceThatNeverArrivesIsJudgedAfterTheTimeout_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_APieceThatNeverArrivesIsJudgedAfterTheTimeout_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_AResetRejectsAnAddPieceInTheSameDrain_SpawnParams
{
}

namespace UMars_AutoTest_Searing_AResetRejectsAnAddPieceInTheSameDrain
{
    FMars_AutoTest_Searing_AResetRejectsAnAddPieceInTheSameDrain_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_AResetRejectsAnAddPieceInTheSameDrain_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_ATakeOutLoadsTheTrayAndReadoptsARefusal_SpawnParams
{
}

namespace UMars_AutoTest_Searing_ATakeOutLoadsTheTrayAndReadoptsARefusal
{
    FMars_AutoTest_Searing_ATakeOutLoadsTheTrayAndReadoptsARefusal_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_ATakeOutLoadsTheTrayAndReadoptsARefusal_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_AThinSliceRestingInThePanIsNotLost_SpawnParams
{
}

namespace UMars_AutoTest_Searing_AThinSliceRestingInThePanIsNotLost
{
    FMars_AutoTest_Searing_AThinSliceRestingInThePanIsNotLost_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_AThinSliceRestingInThePanIsNotLost_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_DrainsTheInboxAsAddPiece_SpawnParams
{
}

namespace UMars_AutoTest_Searing_DrainsTheInboxAsAddPiece
{
    FMars_AutoTest_Searing_DrainsTheInboxAsAddPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_DrainsTheInboxAsAddPiece_SpawnParams();
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
struct FMars_AutoTest_Searing_ResetKeepsEveryPieceLevelsThePanAndChills_SpawnParams
{
}

namespace UMars_AutoTest_Searing_ResetKeepsEveryPieceLevelsThePanAndChills
{
    FMars_AutoTest_Searing_ResetKeepsEveryPieceLevelsThePanAndChills_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_ResetKeepsEveryPieceLevelsThePanAndChills_SpawnParams();
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
struct FMars_AutoTest_Searing_StationDestroyedEndsItsPieces_SpawnParams
{
}

namespace UMars_AutoTest_Searing_StationDestroyedEndsItsPieces
{
    FMars_AutoTest_Searing_StationDestroyedEndsItsPieces_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_StationDestroyedEndsItsPieces_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_SwirlAfterASleepingSteak_SpawnParams
{
}

namespace UMars_AutoTest_Searing_SwirlAfterASleepingSteak
{
    FMars_AutoTest_Searing_SwirlAfterASleepingSteak_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_SwirlAfterASleepingSteak_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_SwirlAloneKeepsTheSteakFlat_SpawnParams
{
}

namespace UMars_AutoTest_Searing_SwirlAloneKeepsTheSteakFlat
{
    FMars_AutoTest_Searing_SwirlAloneKeepsTheSteakFlat_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_SwirlAloneKeepsTheSteakFlat_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_SwirlWithTheSteakAtTheWall_SpawnParams
{
}

namespace UMars_AutoTest_Searing_SwirlWithTheSteakAtTheWall
{
    FMars_AutoTest_Searing_SwirlWithTheSteakAtTheWall_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_SwirlWithTheSteakAtTheWall_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_TakeOutHandsReadyPiecesBackWithTheirCookState_SpawnParams
{
}

namespace UMars_AutoTest_Searing_TakeOutHandsReadyPiecesBackWithTheirCookState
{
    FMars_AutoTest_Searing_TakeOutHandsReadyPiecesBackWithTheirCookState_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_TakeOutHandsReadyPiecesBackWithTheirCookState_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndNothingReplacesIt_SpawnParams
{
}

namespace UMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndNothingReplacesIt
{
    FMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndNothingReplacesIt_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndNothingReplacesIt_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_TeleportingEachFaceDownMakesThePieceReady_SpawnParams
{
}

namespace UMars_AutoTest_Searing_TeleportingEachFaceDownMakesThePieceReady
{
    FMars_AutoTest_Searing_TeleportingEachFaceDownMakesThePieceReady_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_TeleportingEachFaceDownMakesThePieceReady_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Searing_TwoPiecesSearIndependently_SpawnParams
{
}

namespace UMars_AutoTest_Searing_TwoPiecesSearIndependently
{
    FMars_AutoTest_Searing_TwoPiecesSearIndependently_SpawnParams Params()
    {
        return FMars_AutoTest_Searing_TwoPiecesSearIndependently_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_AnAdmittedJointCannotBePickedUp_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_AnAdmittedJointCannotBePickedUp
{
    FMars_AutoTest_SearingStation_AnAdmittedJointCannotBePickedUp_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_AnAdmittedJointCannotBePickedUp_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_AnOperatorFeedsThroughTheIntentReader_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_AnOperatorFeedsThroughTheIntentReader
{
    FMars_AutoTest_SearingStation_AnOperatorFeedsThroughTheIntentReader_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_AnOperatorFeedsThroughTheIntentReader_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_APlatterSourcedPieceSearsAFaceThrough_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_APlatterSourcedPieceSearsAFaceThrough
{
    FMars_AutoTest_SearingStation_APlatterSourcedPieceSearsAFaceThrough_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_APlatterSourcedPieceSearsAFaceThrough_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_ASlabCutAtTheBenchSearsAFaceThroughOnThePan_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_ASlabCutAtTheBenchSearsAFaceThroughOnThePan
{
    FMars_AutoTest_SearingStation_ASlabCutAtTheBenchSearsAFaceThroughOnThePan_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_ASlabCutAtTheBenchSearsAFaceThroughOnThePan_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_DressingFollowsTheSteak_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_DressingFollowsTheSteak
{
    FMars_AutoTest_SearingStation_DressingFollowsTheSteak_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_DressingFollowsTheSteak_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool
{
    FMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_DressingGivesEachPieceItsOwnPool_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_FeedTakesFromTheTrayAndTakeOutLoadsTheOther_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_FeedTakesFromTheTrayAndTakeOutLoadsTheOther
{
    FMars_AutoTest_SearingStation_FeedTakesFromTheTrayAndTakeOutLoadsTheOther_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_FeedTakesFromTheTrayAndTakeOutLoadsTheOther_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_InputDockRefusesVegetablesAndTakesMeat_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_InputDockRefusesVegetablesAndTakesMeat
{
    FMars_AutoTest_SearingStation_InputDockRefusesVegetablesAndTakesMeat_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_InputDockRefusesVegetablesAndTakesMeat_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_LeavingMidTransferStillAdmits_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_LeavingMidTransferStillAdmits
{
    FMars_AutoTest_SearingStation_LeavingMidTransferStillAdmits_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_LeavingMidTransferStillAdmits_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray_SpawnParams
{
}

namespace UMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray
{
    FMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray_SpawnParams Params()
    {
        return FMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray_SpawnParams();
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
struct FMars_AutoTest_Station_AnOperatedStationStaysFocusableAndRefusesUse_SpawnParams
{
}

namespace UMars_AutoTest_Station_AnOperatedStationStaysFocusableAndRefusesUse
{
    FMars_AutoTest_Station_AnOperatedStationStaysFocusableAndRefusesUse_SpawnParams Params()
    {
        return FMars_AutoTest_Station_AnOperatedStationStaysFocusableAndRefusesUse_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_AnOperatorReservesThroughTheUseInteraction_SpawnParams
{
}

namespace UMars_AutoTest_Station_AnOperatorReservesThroughTheUseInteraction
{
    FMars_AutoTest_Station_AnOperatorReservesThroughTheUseInteraction_SpawnParams Params()
    {
        return FMars_AutoTest_Station_AnOperatorReservesThroughTheUseInteraction_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_AReserveWhoseGripNeverLandsGivesUp_SpawnParams
{
}

namespace UMars_AutoTest_Station_AReserveWhoseGripNeverLandsGivesUp
{
    FMars_AutoTest_Station_AReserveWhoseGripNeverLandsGivesUp_SpawnParams Params()
    {
        return FMars_AutoTest_Station_AReserveWhoseGripNeverLandsGivesUp_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_AUseWithFullHandsLeavesTheStationFree_SpawnParams
{
}

namespace UMars_AutoTest_Station_AUseWithFullHandsLeavesTheStationFree
{
    FMars_AutoTest_Station_AUseWithFullHandsLeavesTheStationFree_SpawnParams Params()
    {
        return FMars_AutoTest_Station_AUseWithFullHandsLeavesTheStationFree_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_BackLeavesTheStation_SpawnParams
{
}

namespace UMars_AutoTest_Station_BackLeavesTheStation
{
    FMars_AutoTest_Station_BackLeavesTheStation_SpawnParams Params()
    {
        return FMars_AutoTest_Station_BackLeavesTheStation_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Station_DockMarkerIsHostedUnderTheDock_SpawnParams
{
}

namespace UMars_AutoTest_Station_DockMarkerIsHostedUnderTheDock
{
    FMars_AutoTest_Station_DockMarkerIsHostedUnderTheDock_SpawnParams Params()
    {
        return FMars_AutoTest_Station_DockMarkerIsHostedUnderTheDock_SpawnParams();
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
struct FMars_AutoTest_Station_ViewLocalMakesAViewNode_SpawnParams
{
}

namespace UMars_AutoTest_Station_ViewLocalMakesAViewNode
{
    FMars_AutoTest_Station_ViewLocalMakesAViewNode_SpawnParams Params()
    {
        return FMars_AutoTest_Station_ViewLocalMakesAViewNode_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceFx_GaitEmitsOncePerIncrement_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceFx_GaitEmitsOncePerIncrement
{
    FMars_AutoTest_SurfaceFx_GaitEmitsOncePerIncrement_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceFx_GaitEmitsOncePerIncrement_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat
{
    FMars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceFx_ImpactorOverrideWins_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceFx_ImpactorOverrideWins
{
    FMars_AutoTest_SurfaceFx_ImpactorOverrideWins_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceFx_ImpactorOverrideWins_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceFx_ResolveFallsBackExactParentDefault_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceFx_ResolveFallsBackExactParentDefault
{
    FMars_AutoTest_SurfaceFx_ResolveFallsBackExactParentDefault_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceFx_ResolveFallsBackExactParentDefault_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceFx_ShippedTableValidatesAndLoads_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceFx_ShippedTableValidatesAndLoads
{
    FMars_AutoTest_SurfaceFx_ShippedTableValidatesAndLoads_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceFx_ShippedTableValidatesAndLoads_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceFx_ValidateRejectsInvalid_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceFx_ValidateRejectsInvalid
{
    FMars_AutoTest_SurfaceFx_ValidateRejectsInvalid_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceFx_ValidateRejectsInvalid_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_SurfaceFx_VariantByIntensity_SpawnParams
{
}

namespace UMars_AutoTest_SurfaceFx_VariantByIntensity
{
    FMars_AutoTest_SurfaceFx_VariantByIntensity_SpawnParams Params()
    {
        return FMars_AutoTest_SurfaceFx_VariantByIntensity_SpawnParams();
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
struct FMars_AutoTest_TPBody_HoldSpecValidates_SpawnParams
{
}

namespace UMars_AutoTest_TPBody_HoldSpecValidates
{
    FMars_AutoTest_TPBody_HoldSpecValidates_SpawnParams Params()
    {
        return FMars_AutoTest_TPBody_HoldSpecValidates_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_TPBody_SocketGripsCentreInTheHandFrame_SpawnParams
{
}

namespace UMars_AutoTest_TPBody_SocketGripsCentreInTheHandFrame
{
    FMars_AutoTest_TPBody_SocketGripsCentreInTheHandFrame_SpawnParams Params()
    {
        return FMars_AutoTest_TPBody_SocketGripsCentreInTheHandFrame_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_TPBody_SwingMovesTheHoldFrame_SpawnParams
{
}

namespace UMars_AutoTest_TPBody_SwingMovesTheHoldFrame
{
    FMars_AutoTest_TPBody_SwingMovesTheHoldFrame_SpawnParams Params()
    {
        return FMars_AutoTest_TPBody_SwingMovesTheHoldFrame_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_AdmissionNeedsTheHatchOpen_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_AdmissionNeedsTheHatchOpen
{
    FMars_AutoTest_Tumbler_AdmissionNeedsTheHatchOpen_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_AdmissionNeedsTheHatchOpen_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_AdmissionRefusesADuplicateAndAFullDrum_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_AdmissionRefusesADuplicateAndAFullDrum
{
    FMars_AutoTest_Tumbler_AdmissionRefusesADuplicateAndAFullDrum_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_AdmissionRefusesADuplicateAndAFullDrum_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_AHeldGripRocksInsideTheArcAndNeverCompletes_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_AHeldGripRocksInsideTheArcAndNeverCompletes
{
    FMars_AutoTest_Tumbler_AHeldGripRocksInsideTheArcAndNeverCompletes_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_AHeldGripRocksInsideTheArcAndNeverCompletes_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_AnAdoptedPieceIsTheOneReleased_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_AnAdoptedPieceIsTheOneReleased
{
    FMars_AutoTest_Tumbler_AnAdoptedPieceIsTheOneReleased_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_AnAdoptedPieceIsTheOneReleased_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum
{
    FMars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_AResetDestroysEveryPiece_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_AResetDestroysEveryPiece
{
    FMars_AutoTest_Tumbler_AResetDestroysEveryPiece_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_AResetDestroysEveryPiece_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_ATakeOutWritesCrumb_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_ATakeOutWritesCrumb
{
    FMars_AutoTest_Tumbler_ATakeOutWritesCrumb_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_ATakeOutWritesCrumb_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_CoverageGrowsOnlyWithPieceMotionAndNeverFalls_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_CoverageGrowsOnlyWithPieceMotionAndNeverFalls
{
    FMars_AutoTest_Tumbler_CoverageGrowsOnlyWithPieceMotionAndNeverFalls_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_CoverageGrowsOnlyWithPieceMotionAndNeverFalls_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_LeavingCancelsTheGripAndKeepsTheBatch_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_LeavingCancelsTheGripAndKeepsTheBatch
{
    FMars_AutoTest_Tumbler_LeavingCancelsTheGripAndKeepsTheBatch_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_LeavingCancelsTheGripAndKeepsTheBatch_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs
{
    FMars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_Tumbler_TheHatchTogglesOnlyAtHomeAndSettled_SpawnParams
{
}

namespace UMars_AutoTest_Tumbler_TheHatchTogglesOnlyAtHomeAndSettled
{
    FMars_AutoTest_Tumbler_TheHatchTogglesOnlyAtHomeAndSettled_SpawnParams Params()
    {
        return FMars_AutoTest_Tumbler_TheHatchTogglesOnlyAtHomeAndSettled_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut_SpawnParams
{
}

namespace UMars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut
{
    FMars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut_SpawnParams Params()
    {
        return FMars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased
{
    FMars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_ADroppedItemWithinReachIsPickedUpByATap_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_ADroppedItemWithinReachIsPickedUpByATap
{
    FMars_AutoTest_WorldItem_ADroppedItemWithinReachIsPickedUpByATap_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_ADroppedItemWithinReachIsPickedUpByATap_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AFoodItemStowsToABagSlotAndIsHeldWhenSelected_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AFoodItemStowsToABagSlotAndIsHeldWhenSelected
{
    FMars_AutoTest_WorldItem_AFoodItemStowsToABagSlotAndIsHeldWhenSelected_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AFoodItemStowsToABagSlotAndIsHeldWhenSelected_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn
{
    FMars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AHotbarGateCannotReenableALedgerHeldPickup_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AHotbarGateCannotReenableALedgerHeldPickup
{
    FMars_AutoTest_WorldItem_AHotbarGateCannotReenableALedgerHeldPickup_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AHotbarGateCannotReenableALedgerHeldPickup_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AMountWhoseBodyFailsSetupCommitsWithoutIt_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AMountWhoseBodyFailsSetupCommitsWithoutIt
{
    FMars_AutoTest_WorldItem_AMountWhoseBodyFailsSetupCommitsWithoutIt_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AMountWhoseBodyFailsSetupCommitsWithoutIt_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AnItemWhoseCarrierDiesEndsItself_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AnItemWhoseCarrierDiesEndsItself
{
    FMars_AutoTest_WorldItem_AnItemWhoseCarrierDiesEndsItself_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AnItemWhoseCarrierDiesEndsItself_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AnItemWhoseHolderDiesEndsItself_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AnItemWhoseHolderDiesEndsItself
{
    FMars_AutoTest_WorldItem_AnItemWhoseHolderDiesEndsItself_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AnItemWhoseHolderDiesEndsItself_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_APickupTheGlovesRefuseLandsAtOnce_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_APickupTheGlovesRefuseLandsAtOnce
{
    FMars_AutoTest_WorldItem_APickupTheGlovesRefuseLandsAtOnce_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_APickupTheGlovesRefuseLandsAtOnce_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_APickupWaitsForTheGrip_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_APickupWaitsForTheGrip
{
    FMars_AutoTest_WorldItem_APickupWaitsForTheGrip_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_APickupWaitsForTheGrip_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AReleaseWhoseTransferFailsChangesNothing_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AReleaseWhoseTransferFailsChangesNothing
{
    FMars_AutoTest_WorldItem_AReleaseWhoseTransferFailsChangesNothing_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AReleaseWhoseTransferFailsChangesNothing_SpawnParams();
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
struct FMars_AutoTest_WorldItem_ASecondTapAfterASpentHoldPicksUpAgain_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_ASecondTapAfterASpentHoldPicksUpAgain
{
    FMars_AutoTest_WorldItem_ASecondTapAfterASpentHoldPicksUpAgain_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_ASecondTapAfterASpentHoldPicksUpAgain_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_AThrownItemIsPickedUpByATap_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_AThrownItemIsPickedUpByATap
{
    FMars_AutoTest_WorldItem_AThrownItemIsPickedUpByATap_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_AThrownItemIsPickedUpByATap_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTest_WorldItem_OnMountSettledFiresOnceAtTheEndOfTheArrival_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_OnMountSettledFiresOnceAtTheEndOfTheArrival
{
    FMars_AutoTest_WorldItem_OnMountSettledFiresOnceAtTheEndOfTheArrival_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_OnMountSettledFiresOnceAtTheEndOfTheArrival_SpawnParams();
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
struct FMars_AutoTest_WorldItem_TheMountFollowsTheItemsInventory_SpawnParams
{
}

namespace UMars_AutoTest_WorldItem_TheMountFollowsTheItemsInventory
{
    FMars_AutoTest_WorldItem_TheMountFollowsTheItemsInventory_SpawnParams Params()
    {
        return FMars_AutoTest_WorldItem_TheMountFollowsTheItemsInventory_SpawnParams();
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
struct FMars_AutoTestHelper_FoodItem_RefusingHolder_SpawnParams
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

    FMars_AutoTestHelper_FoodItem_RefusingHolder_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_AutoTestHelper_FoodItem_RefusingHolder
{
    FMars_AutoTestHelper_FoodItem_RefusingHolder_SpawnParams Params()
    {
        return FMars_AutoTestHelper_FoodItem_RefusingHolder_SpawnParams();
    }

    FMars_AutoTestHelper_FoodItem_RefusingHolder_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_AutoTestHelper_FoodItem_RefusingHolder_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_AutoTestHelper_WhileLiveWorkTask_SpawnParams
{
}

namespace UMars_AutoTestHelper_WhileLiveWorkTask
{
    FMars_AutoTestHelper_WhileLiveWorkTask_SpawnParams Params()
    {
        return FMars_AutoTestHelper_WhileLiveWorkTask_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestHelper_WorldItem_RefusingHolder_SpawnParams
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

    FMars_AutoTestHelper_WorldItem_RefusingHolder_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_AutoTestHelper_WorldItem_RefusingHolder
{
    FMars_AutoTestHelper_WorldItem_RefusingHolder_SpawnParams Params()
    {
        return FMars_AutoTestHelper_WorldItem_RefusingHolder_SpawnParams();
    }

    FMars_AutoTestHelper_WorldItem_RefusingHolder_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_AutoTestHelper_WorldItem_RefusingHolder_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
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
struct FMars_AutoTestState_CarrierHands_SpawnParams
{
}

namespace UMars_AutoTestState_CarrierHands
{
    FMars_AutoTestState_CarrierHands_SpawnParams Params()
    {
        return FMars_AutoTestState_CarrierHands_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_FocusRig_SpawnParams
{
}

namespace UMars_AutoTestState_FocusRig
{
    FMars_AutoTestState_FocusRig_SpawnParams Params()
    {
        return FMars_AutoTestState_FocusRig_SpawnParams();
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
struct FMars_AutoTestState_HandsSubSmRig_SpawnParams
{
}

namespace UMars_AutoTestState_HandsSubSmRig
{
    FMars_AutoTestState_HandsSubSmRig_SpawnParams Params()
    {
        return FMars_AutoTestState_HandsSubSmRig_SpawnParams();
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
struct FMars_AutoTestState_OperatorRig_SpawnParams
{
}

namespace UMars_AutoTestState_OperatorRig
{
    FMars_AutoTestState_OperatorRig_SpawnParams Params()
    {
        return FMars_AutoTestState_OperatorRig_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_OperatorRigOperating_SpawnParams
{
}

namespace UMars_AutoTestState_OperatorRigOperating
{
    FMars_AutoTestState_OperatorRigOperating_SpawnParams Params()
    {
        return FMars_AutoTestState_OperatorRigOperating_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_OperatorRigRoam_SpawnParams
{
}

namespace UMars_AutoTestState_OperatorRigRoam
{
    FMars_AutoTestState_OperatorRigRoam_SpawnParams Params()
    {
        return FMars_AutoTestState_OperatorRigRoam_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_PickupByPressRig_SpawnParams
{
}

namespace UMars_AutoTestState_PickupByPressRig
{
    FMars_AutoTestState_PickupByPressRig_SpawnParams Params()
    {
        return FMars_AutoTestState_PickupByPressRig_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_PlayerPathRig_SpawnParams
{
}

namespace UMars_AutoTestState_PlayerPathRig
{
    FMars_AutoTestState_PlayerPathRig_SpawnParams Params()
    {
        return FMars_AutoTestState_PlayerPathRig_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_UseIntentRig_SpawnParams
{
}

namespace UMars_AutoTestState_UseIntentRig
{
    FMars_AutoTestState_UseIntentRig_SpawnParams Params()
    {
        return FMars_AutoTestState_UseIntentRig_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestState_WhileLiveWork_SpawnParams
{
}

namespace UMars_AutoTestState_WhileLiveWork
{
    FMars_AutoTestState_WhileLiveWork_SpawnParams Params()
    {
        return FMars_AutoTestState_WhileLiveWork_SpawnParams();
    }
}

USTRUCT()
struct FMars_AutoTestTask_OperatorRigModes_SpawnParams
{
}

namespace UMars_AutoTestTask_OperatorRigModes
{
    FMars_AutoTestTask_OperatorRigModes_SpawnParams Params()
    {
        return FMars_AutoTestTask_OperatorRigModes_SpawnParams();
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
struct FMars_BatterStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    UPROPERTY()
    FMars_CookingFeed_Spec Feed;

    UPROPERTY()
    FMars_Batter_Spec Batter = FMars_Batter_Spec();

    FMars_BatterStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Batter_Spec InBatter)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        Feed = InFeed;
        Batter = InBatter;
    }
}

namespace UMars_BatterStation_EntityScript
{
    FMars_BatterStation_EntityScript_SpawnParams Params()
    {
        return FMars_BatterStation_EntityScript_SpawnParams();
    }

    FMars_BatterStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Batter_Spec InBatter)
    {
        return FMars_BatterStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InFeed, InBatter);
    }
}

USTRUCT()
struct FMars_CameraLayer_Station_SpawnParams
{
}

namespace UMars_CameraLayer_Station
{
    FMars_CameraLayer_Station_SpawnParams Params()
    {
        return FMars_CameraLayer_Station_SpawnParams();
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

    UPROPERTY()
    bool DebugDrawAttack = false;

    FMars_Crawler_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals, bool InDebugDrawAttack)
    {
        SpawnTransform = InSpawnTransform;
        Spec = InSpec;
        Color = InColor;
        WithVisuals = InWithVisuals;
        DebugDrawAttack = InDebugDrawAttack;
    }
}

namespace UMars_Crawler_EntityScript
{
    FMars_Crawler_EntityScript_SpawnParams Params()
    {
        return FMars_Crawler_EntityScript_SpawnParams();
    }

    FMars_Crawler_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals, bool InDebugDrawAttack)
    {
        return FMars_Crawler_EntityScript_SpawnParams(InSpawnTransform, InSpec, InColor, InWithVisuals, InDebugDrawAttack);
    }
}

USTRUCT()
struct FMars_CuttingStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    UPROPERTY()
    FMars_CookingFeed_Spec Feed;

    UPROPERTY()
    FMars_Cutting_Spec Cutting = FMars_Cutting_Spec();

    FMars_CuttingStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Cutting_Spec InCutting)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        Feed = InFeed;
        Cutting = InCutting;
    }
}

namespace UMars_CuttingStation_EntityScript
{
    FMars_CuttingStation_EntityScript_SpawnParams Params()
    {
        return FMars_CuttingStation_EntityScript_SpawnParams();
    }

    FMars_CuttingStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Cutting_Spec InCutting)
    {
        return FMars_CuttingStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InFeed, InCutting);
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
struct FMars_FoodItem_EntityScript_SpawnParams
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

    FMars_FoodItem_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_FoodItem_EntityScript
{
    FMars_FoodItem_EntityScript_SpawnParams Params()
    {
        return FMars_FoodItem_EntityScript_SpawnParams();
    }

    FMars_FoodItem_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_FoodItem_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_FoodItem_MeatSlab_EntityScript_SpawnParams
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

    FMars_FoodItem_MeatSlab_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_FoodItem_MeatSlab_EntityScript
{
    FMars_FoodItem_MeatSlab_EntityScript_SpawnParams Params()
    {
        return FMars_FoodItem_MeatSlab_EntityScript_SpawnParams();
    }

    FMars_FoodItem_MeatSlab_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_FoodItem_MeatSlab_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_FoodItem_MushroomSlice_EntityScript_SpawnParams
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

    FMars_FoodItem_MushroomSlice_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_FoodItem_MushroomSlice_EntityScript
{
    FMars_FoodItem_MushroomSlice_EntityScript_SpawnParams Params()
    {
        return FMars_FoodItem_MushroomSlice_EntityScript_SpawnParams();
    }

    FMars_FoodItem_MushroomSlice_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_FoodItem_MushroomSlice_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
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
struct FMars_FryStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    UPROPERTY()
    FMars_CookingFeed_Spec Feed;

    UPROPERTY()
    FMars_Fry_Spec Fry = FMars_Fry_Spec();

    UPROPERTY()
    FMars_Implement_Spec SkimmerImplement = FMars_Implement_Spec();

    FMars_FryStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Fry_Spec InFry, FMars_Implement_Spec InSkimmerImplement)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        Feed = InFeed;
        Fry = InFry;
        SkimmerImplement = InSkimmerImplement;
    }
}

namespace UMars_FryStation_EntityScript
{
    FMars_FryStation_EntityScript_SpawnParams Params()
    {
        return FMars_FryStation_EntityScript_SpawnParams();
    }

    FMars_FryStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Fry_Spec InFry, FMars_Implement_Spec InSkimmerImplement)
    {
        return FMars_FryStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InFeed, InFry, InSkimmerImplement);
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
struct FMars_Platter_EntityScript_SpawnParams
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

    FMars_Platter_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Platter_EntityScript
{
    FMars_Platter_EntityScript_SpawnParams Params()
    {
        return FMars_Platter_EntityScript_SpawnParams();
    }

    FMars_Platter_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Platter_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
    }
}

USTRUCT()
struct FMars_Platter_Large_EntityScript_SpawnParams
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

    FMars_Platter_Large_EntityScript_SpawnParams(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
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

namespace UMars_Platter_Large_EntityScript
{
    FMars_Platter_Large_EntityScript_SpawnParams Params()
    {
        return FMars_Platter_Large_EntityScript_SpawnParams();
    }

    FMars_Platter_Large_EntityScript_SpawnParams Params(FTransform InSpawnTransform, TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, EMars_WorldItem_Mode InMode, FCk_Handle InAttachTo, FTransform InAttachOffset, FCk_Handle_Item InSourceItem, FCk_Handle_Inventory InSourceInventory, FVector InLaunchVelocity, FVector InAngularVelocityDeg, FMars_WorldItem_Arrival InArriveFrom)
    {
        return FMars_Platter_Large_EntityScript_SpawnParams(InSpawnTransform, InDefinition, InMode, InAttachTo, InAttachOffset, InSourceItem, InSourceInventory, InLaunchVelocity, InAngularVelocityDeg, InArriveFrom);
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
struct FMars_Sandbox_AggressionLever_EntityScript_SpawnParams
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
    FText PromptText = FText::FromString("Rouse the crawlers");

    FMars_Sandbox_AggressionLever_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        SpawnTransform = InSpawnTransform;
        Control = InControl;
        Source = InSource;
        PulledAngle = InPulledAngle;
        MoveDuration = InMoveDuration;
        PromptText = InPromptText;
    }
}

namespace UMars_Sandbox_AggressionLever_EntityScript
{
    FMars_Sandbox_AggressionLever_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_AggressionLever_EntityScript_SpawnParams();
    }

    FMars_Sandbox_AggressionLever_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Control_Spec InControl, FMars_MechanismSource_Spec InSource, float32 InPulledAngle, float32 InMoveDuration, FText InPromptText)
    {
        return FMars_Sandbox_AggressionLever_EntityScript_SpawnParams(InSpawnTransform, InControl, InSource, InPulledAngle, InMoveDuration, InPromptText);
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

    UPROPERTY()
    bool DebugDrawAttack = false;

    FMars_Sandbox_Crawler4_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals, bool InDebugDrawAttack)
    {
        SpawnTransform = InSpawnTransform;
        Spec = InSpec;
        Color = InColor;
        WithVisuals = InWithVisuals;
        DebugDrawAttack = InDebugDrawAttack;
    }
}

namespace UMars_Sandbox_Crawler4_EntityScript
{
    FMars_Sandbox_Crawler4_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_Crawler4_EntityScript_SpawnParams();
    }

    FMars_Sandbox_Crawler4_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals, bool InDebugDrawAttack)
    {
        return FMars_Sandbox_Crawler4_EntityScript_SpawnParams(InSpawnTransform, InSpec, InColor, InWithVisuals, InDebugDrawAttack);
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

    UPROPERTY()
    bool DebugDrawAttack = false;

    FMars_Sandbox_Crawler6_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals, bool InDebugDrawAttack)
    {
        SpawnTransform = InSpawnTransform;
        Spec = InSpec;
        Color = InColor;
        WithVisuals = InWithVisuals;
        DebugDrawAttack = InDebugDrawAttack;
    }
}

namespace UMars_Sandbox_Crawler6_EntityScript
{
    FMars_Sandbox_Crawler6_EntityScript_SpawnParams Params()
    {
        return FMars_Sandbox_Crawler6_EntityScript_SpawnParams();
    }

    FMars_Sandbox_Crawler6_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Crawler_Spec InSpec, FLinearColor InColor, bool InWithVisuals, bool InDebugDrawAttack)
    {
        return FMars_Sandbox_Crawler6_EntityScript_SpawnParams(InSpawnTransform, InSpec, InColor, InWithVisuals, InDebugDrawAttack);
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
    FMars_CookingFeed_Spec Feed;

    UPROPERTY()
    FMars_Searing_Spec Searing = FMars_Searing_Spec();

    UPROPERTY()
    FMars_Implement_Spec Implement = FMars_Implement_Spec();

    FMars_SearingStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Searing_Spec InSearing, FMars_Implement_Spec InImplement)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        Feed = InFeed;
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

    FMars_SearingStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Searing_Spec InSearing, FMars_Implement_Spec InImplement)
    {
        return FMars_SearingStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InFeed, InSearing, InImplement);
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
struct FMars_SmCondition_Crawler_EngageStage_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_EngageStage
{
    FMars_SmCondition_Crawler_EngageStage_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_EngageStage_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_EngageStage_Approach_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_EngageStage_Approach
{
    FMars_SmCondition_Crawler_EngageStage_Approach_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_EngageStage_Approach_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_EngageStage_Attack_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_EngageStage_Attack
{
    FMars_SmCondition_Crawler_EngageStage_Attack_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_EngageStage_Attack_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_EngageStage_Prepare_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_EngageStage_Prepare
{
    FMars_SmCondition_Crawler_EngageStage_Prepare_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_EngageStage_Prepare_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_Crawler_EngageStage_Wait_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_EngageStage_Wait
{
    FMars_SmCondition_Crawler_EngageStage_Wait_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_EngageStage_Wait_SpawnParams();
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
struct FMars_SmCondition_Crawler_LeafEngage_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafEngage
{
    FMars_SmCondition_Crawler_LeafEngage_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafEngage_SpawnParams();
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
struct FMars_SmCondition_Crawler_LeafNotEngage_SpawnParams
{
}

namespace UMars_SmCondition_Crawler_LeafNotEngage
{
    FMars_SmCondition_Crawler_LeafNotEngage_SpawnParams Params()
    {
        return FMars_SmCondition_Crawler_LeafNotEngage_SpawnParams();
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
struct FMars_SmCondition_InteractableIsFocusable_SpawnParams
{
}

namespace UMars_SmCondition_InteractableIsFocusable
{
    FMars_SmCondition_InteractableIsFocusable_SpawnParams Params()
    {
        return FMars_SmCondition_InteractableIsFocusable_SpawnParams();
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
struct FMars_SmCondition_InteractableIsNotFocusable_SpawnParams
{
}

namespace UMars_SmCondition_InteractableIsNotFocusable
{
    FMars_SmCondition_InteractableIsNotFocusable_SpawnParams Params()
    {
        return FMars_SmCondition_InteractableIsNotFocusable_SpawnParams();
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
struct FMars_SmCondition_InteractionCompleted_SpawnParams
{
}

namespace UMars_SmCondition_InteractionCompleted
{
    FMars_SmCondition_InteractionCompleted_SpawnParams Params()
    {
        return FMars_SmCondition_InteractionCompleted_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractionEnded_SpawnParams
{
}

namespace UMars_SmCondition_InteractionEnded
{
    FMars_SmCondition_InteractionEnded_SpawnParams Params()
    {
        return FMars_SmCondition_InteractionEnded_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractionGone_SpawnParams
{
}

namespace UMars_SmCondition_InteractionGone
{
    FMars_SmCondition_InteractionGone_SpawnParams Params()
    {
        return FMars_SmCondition_InteractionGone_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_InteractionLive_SpawnParams
{
}

namespace UMars_SmCondition_InteractionLive
{
    FMars_SmCondition_InteractionLive_SpawnParams Params()
    {
        return FMars_SmCondition_InteractionLive_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmCondition_IsAliveAndNotDepleted_SpawnParams
{
}

namespace UMars_SmCondition_IsAliveAndNotDepleted
{
    FMars_SmCondition_IsAliveAndNotDepleted_SpawnParams Params()
    {
        return FMars_SmCondition_IsAliveAndNotDepleted_SpawnParams();
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
struct FMars_SmCondition_IsDownedOrDepleted_SpawnParams
{
}

namespace UMars_SmCondition_IsDownedOrDepleted
{
    FMars_SmCondition_IsDownedOrDepleted_SpawnParams Params()
    {
        return FMars_SmCondition_IsDownedOrDepleted_SpawnParams();
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
struct FMars_SmState_Batter_Idle_SpawnParams
{
}

namespace UMars_SmState_Batter_Idle
{
    FMars_SmState_Batter_Idle_SpawnParams Params()
    {
        return FMars_SmState_Batter_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Batter_Operated_SpawnParams
{
}

namespace UMars_SmState_Batter_Operated
{
    FMars_SmState_Batter_Operated_SpawnParams Params()
    {
        return FMars_SmState_Batter_Operated_SpawnParams();
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
struct FMars_SmState_Crawler_Engage_SpawnParams
{
}

namespace UMars_SmState_Crawler_Engage
{
    FMars_SmState_Crawler_Engage_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Engage_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Engage_Approach_SpawnParams
{
}

namespace UMars_SmState_Crawler_Engage_Approach
{
    FMars_SmState_Crawler_Engage_Approach_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Engage_Approach_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Engage_Attack_SpawnParams
{
}

namespace UMars_SmState_Crawler_Engage_Attack
{
    FMars_SmState_Crawler_Engage_Attack_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Engage_Attack_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Engage_Prepare_SpawnParams
{
}

namespace UMars_SmState_Crawler_Engage_Prepare
{
    FMars_SmState_Crawler_Engage_Prepare_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Engage_Prepare_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Crawler_Engage_Wait_SpawnParams
{
}

namespace UMars_SmState_Crawler_Engage_Wait
{
    FMars_SmState_Crawler_Engage_Wait_SpawnParams Params()
    {
        return FMars_SmState_Crawler_Engage_Wait_SpawnParams();
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
struct FMars_SmState_Cutting_Idle_SpawnParams
{
}

namespace UMars_SmState_Cutting_Idle
{
    FMars_SmState_Cutting_Idle_SpawnParams Params()
    {
        return FMars_SmState_Cutting_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Cutting_Operated_SpawnParams
{
}

namespace UMars_SmState_Cutting_Operated
{
    FMars_SmState_Cutting_Operated_SpawnParams Params()
    {
        return FMars_SmState_Cutting_Operated_SpawnParams();
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
struct FMars_SmState_Fry_Idle_SpawnParams
{
}

namespace UMars_SmState_Fry_Idle
{
    FMars_SmState_Fry_Idle_SpawnParams Params()
    {
        return FMars_SmState_Fry_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Fry_Operated_SpawnParams
{
}

namespace UMars_SmState_Fry_Operated
{
    FMars_SmState_Fry_Operated_SpawnParams Params()
    {
        return FMars_SmState_Fry_Operated_SpawnParams();
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
struct FMars_SmState_InteractTarget_Failed_SpawnParams
{
}

namespace UMars_SmState_InteractTarget_Failed
{
    FMars_SmState_InteractTarget_Failed_SpawnParams Params()
    {
        return FMars_SmState_InteractTarget_Failed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_InteractTarget_Succeeded_SpawnParams
{
}

namespace UMars_SmState_InteractTarget_Succeeded
{
    FMars_SmState_InteractTarget_Succeeded_SpawnParams Params()
    {
        return FMars_SmState_InteractTarget_Succeeded_SpawnParams();
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
struct FMars_SmState_Platter_Interact_SpawnParams
{
}

namespace UMars_SmState_Platter_Interact
{
    FMars_SmState_Platter_Interact_SpawnParams Params()
    {
        return FMars_SmState_Platter_Interact_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_PlatterDock_Interact_SpawnParams
{
}

namespace UMars_SmState_PlatterDock_Interact
{
    FMars_SmState_PlatterDock_Interact_SpawnParams Params()
    {
        return FMars_SmState_PlatterDock_Interact_SpawnParams();
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
struct FMars_SmState_Tumbler_Idle_SpawnParams
{
}

namespace UMars_SmState_Tumbler_Idle
{
    FMars_SmState_Tumbler_Idle_SpawnParams Params()
    {
        return FMars_SmState_Tumbler_Idle_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmState_Tumbler_Operated_SpawnParams
{
}

namespace UMars_SmState_Tumbler_Operated
{
    FMars_SmState_Tumbler_Operated_SpawnParams Params()
    {
        return FMars_SmState_Tumbler_Operated_SpawnParams();
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
struct FMars_SmTask_Batter_LiftOnExit_SpawnParams
{
}

namespace UMars_SmTask_Batter_LiftOnExit
{
    FMars_SmTask_Batter_LiftOnExit_SpawnParams Params()
    {
        return FMars_SmTask_Batter_LiftOnExit_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Batter_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_Batter_OperatorHints
{
    FMars_SmTask_Batter_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_Batter_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Batter_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_Batter_OperatorInput
{
    FMars_SmTask_Batter_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_Batter_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_BatterFeed_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_BatterFeed_OperatorInput
{
    FMars_SmTask_BatterFeed_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_BatterFeed_OperatorInput_SpawnParams();
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
struct FMars_SmTask_Crawler_Engage_Approach_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Engage_Approach
{
    FMars_SmTask_Crawler_Engage_Approach_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Engage_Approach_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_Engage_Attack_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Engage_Attack
{
    FMars_SmTask_Crawler_Engage_Attack_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Engage_Attack_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_Engage_Prepare_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Engage_Prepare
{
    FMars_SmTask_Crawler_Engage_Prepare_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Engage_Prepare_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_Engage_Wait_SpawnParams
{
}

namespace UMars_SmTask_Crawler_Engage_Wait
{
    FMars_SmTask_Crawler_Engage_Wait_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_Engage_Wait_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_EngageStage_SpawnParams
{
}

namespace UMars_SmTask_Crawler_EngageStage
{
    FMars_SmTask_Crawler_EngageStage_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_EngageStage_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Crawler_EngageSubSm_SpawnParams
{
}

namespace UMars_SmTask_Crawler_EngageSubSm
{
    FMars_SmTask_Crawler_EngageSubSm_SpawnParams Params()
    {
        return FMars_SmTask_Crawler_EngageSubSm_SpawnParams();
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
struct FMars_SmTask_Cutting_CutBridge_SpawnParams
{
}

namespace UMars_SmTask_Cutting_CutBridge
{
    FMars_SmTask_Cutting_CutBridge_SpawnParams Params()
    {
        return FMars_SmTask_Cutting_CutBridge_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Cutting_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_Cutting_OperatorHints
{
    FMars_SmTask_Cutting_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_Cutting_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Cutting_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_Cutting_OperatorInput
{
    FMars_SmTask_Cutting_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_Cutting_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Cutting_ResetOnEnter_SpawnParams
{
}

namespace UMars_SmTask_Cutting_ResetOnEnter
{
    FMars_SmTask_Cutting_ResetOnEnter_SpawnParams Params()
    {
        return FMars_SmTask_Cutting_ResetOnEnter_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_CuttingFeed_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_CuttingFeed_OperatorHints
{
    FMars_SmTask_CuttingFeed_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_CuttingFeed_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_CuttingFeed_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_CuttingFeed_OperatorInput
{
    FMars_SmTask_CuttingFeed_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_CuttingFeed_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Downed_Lockdown_SpawnParams
{
}

namespace UMars_SmTask_Downed_Lockdown
{
    FMars_SmTask_Downed_Lockdown_SpawnParams Params()
    {
        return FMars_SmTask_Downed_Lockdown_SpawnParams();
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
struct FMars_SmTask_EndInteraction_Failed_SpawnParams
{
}

namespace UMars_SmTask_EndInteraction_Failed
{
    FMars_SmTask_EndInteraction_Failed_SpawnParams Params()
    {
        return FMars_SmTask_EndInteraction_Failed_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_EndInteraction_Succeeded_SpawnParams
{
}

namespace UMars_SmTask_EndInteraction_Succeeded
{
    FMars_SmTask_EndInteraction_Succeeded_SpawnParams Params()
    {
        return FMars_SmTask_EndInteraction_Succeeded_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Fry_DriveOnEnter_SpawnParams
{
}

namespace UMars_SmTask_Fry_DriveOnEnter
{
    FMars_SmTask_Fry_DriveOnEnter_SpawnParams Params()
    {
        return FMars_SmTask_Fry_DriveOnEnter_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Fry_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_Fry_OperatorHints
{
    FMars_SmTask_Fry_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_Fry_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Fry_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_Fry_OperatorInput
{
    FMars_SmTask_Fry_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_Fry_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Fry_ResetOnEnter_SpawnParams
{
}

namespace UMars_SmTask_Fry_ResetOnEnter
{
    FMars_SmTask_Fry_ResetOnEnter_SpawnParams Params()
    {
        return FMars_SmTask_Fry_ResetOnEnter_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_FryFeed_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_FryFeed_OperatorHints
{
    FMars_SmTask_FryFeed_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_FryFeed_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_FryFeed_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_FryFeed_OperatorInput
{
    FMars_SmTask_FryFeed_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_FryFeed_OperatorInput_SpawnParams();
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
struct FMars_SmTask_HeldItemDrivesHands_SpawnParams
{
}

namespace UMars_SmTask_HeldItemDrivesHands
{
    FMars_SmTask_HeldItemDrivesHands_SpawnParams Params()
    {
        return FMars_SmTask_HeldItemDrivesHands_SpawnParams();
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
struct FMars_SmTask_HotbarEjectDrops_SpawnParams
{
}

namespace UMars_SmTask_HotbarEjectDrops
{
    FMars_SmTask_HotbarEjectDrops_SpawnParams Params()
    {
        return FMars_SmTask_HotbarEjectDrops_SpawnParams();
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
struct FMars_SmTask_MovementSpeedSync_SpawnParams
{
}

namespace UMars_SmTask_MovementSpeedSync
{
    FMars_SmTask_MovementSpeedSync_SpawnParams Params()
    {
        return FMars_SmTask_MovementSpeedSync_SpawnParams();
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
struct FMars_SmTask_PlaceHeldFood_SpawnParams
{
}

namespace UMars_SmTask_PlaceHeldFood
{
    FMars_SmTask_PlaceHeldFood_SpawnParams Params()
    {
        return FMars_SmTask_PlaceHeldFood_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Platter_PickUp_SpawnParams
{
}

namespace UMars_SmTask_Platter_PickUp
{
    FMars_SmTask_Platter_PickUp_SpawnParams Params()
    {
        return FMars_SmTask_Platter_PickUp_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_PlatterDock_PlaceOrTake_SpawnParams
{
}

namespace UMars_SmTask_PlatterDock_PlaceOrTake
{
    FMars_SmTask_PlatterDock_PlaceOrTake_SpawnParams Params()
    {
        return FMars_SmTask_PlatterDock_PlaceOrTake_SpawnParams();
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
struct FMars_SmTask_StationFeed_Bridge_SpawnParams
{
}

namespace UMars_SmTask_StationFeed_Bridge
{
    FMars_SmTask_StationFeed_Bridge_SpawnParams Params()
    {
        return FMars_SmTask_StationFeed_Bridge_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_StationFeed_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_StationFeed_OperatorHints
{
    FMars_SmTask_StationFeed_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_StationFeed_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_StationFeed_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_StationFeed_OperatorInput
{
    FMars_SmTask_StationFeed_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_StationFeed_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_StationFeed_Source_SpawnParams
{
}

namespace UMars_SmTask_StationFeed_Source
{
    FMars_SmTask_StationFeed_Source_SpawnParams Params()
    {
        return FMars_SmTask_StationFeed_Source_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_StationFeed_TakeOutInput_SpawnParams
{
}

namespace UMars_SmTask_StationFeed_TakeOutInput
{
    FMars_SmTask_StationFeed_TakeOutInput_SpawnParams Params()
    {
        return FMars_SmTask_StationFeed_TakeOutInput_SpawnParams();
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
struct FMars_SmTask_Tumbler_CancelOnExit_SpawnParams
{
}

namespace UMars_SmTask_Tumbler_CancelOnExit
{
    FMars_SmTask_Tumbler_CancelOnExit_SpawnParams Params()
    {
        return FMars_SmTask_Tumbler_CancelOnExit_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Tumbler_OperatorHints_SpawnParams
{
}

namespace UMars_SmTask_Tumbler_OperatorHints
{
    FMars_SmTask_Tumbler_OperatorHints_SpawnParams Params()
    {
        return FMars_SmTask_Tumbler_OperatorHints_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_Tumbler_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_Tumbler_OperatorInput
{
    FMars_SmTask_Tumbler_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_Tumbler_OperatorInput_SpawnParams();
    }
}

USTRUCT()
struct FMars_SmTask_TumblerFeed_OperatorInput_SpawnParams
{
}

namespace UMars_SmTask_TumblerFeed_OperatorInput
{
    FMars_SmTask_TumblerFeed_OperatorInput_SpawnParams Params()
    {
        return FMars_SmTask_TumblerFeed_OperatorInput_SpawnParams();
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
struct FMars_TumblerStation_EntityScript_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Station_Spec Station;

    UPROPERTY()
    FMars_CookingFeed_Spec Feed;

    UPROPERTY()
    FMars_Tumbler_Spec Tumbler = FMars_Tumbler_Spec();

    UPROPERTY()
    FMars_Control_Spec LeverControl = FMars_Control_Spec(ECk_Interaction_CompletionPolicy::Instant, 1.5f, EMars_Control_Behavior::Toggle, 1.0f, false, FMars_Control_Manipulation_Spec(FVector::ZeroVector, 0.012000000104308128f, 0.8500000238418579f, 60.0f, 12.0f, false));

    FMars_TumblerStation_EntityScript_SpawnParams(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Tumbler_Spec InTumbler, FMars_Control_Spec InLeverControl)
    {
        SpawnTransform = InSpawnTransform;
        Station = InStation;
        Feed = InFeed;
        Tumbler = InTumbler;
        LeverControl = InLeverControl;
    }
}

namespace UMars_TumblerStation_EntityScript
{
    FMars_TumblerStation_EntityScript_SpawnParams Params()
    {
        return FMars_TumblerStation_EntityScript_SpawnParams();
    }

    FMars_TumblerStation_EntityScript_SpawnParams Params(FTransform InSpawnTransform, FMars_Station_Spec InStation, FMars_CookingFeed_Spec InFeed, FMars_Tumbler_Spec InTumbler, FMars_Control_Spec InLeverControl)
    {
        return FMars_TumblerStation_EntityScript_SpawnParams(InSpawnTransform, InStation, InFeed, InTumbler, InLeverControl);
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

