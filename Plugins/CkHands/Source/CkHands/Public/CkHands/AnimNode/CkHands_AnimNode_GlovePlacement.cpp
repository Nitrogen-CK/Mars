#include "CkHands_AnimNode_GlovePlacement.h"

#include "CkHands/CkHands_Kernel.h"

#include "CkCore/Ensure/CkEnsure.h"
#include "CkCore/Format/CkFormat.h"

// --------------------------------------------------------------------------------------------------------------------

auto
    FCk_AnimNode_Hands_GlovePlacement::
    GatherDebugData(
        FNodeDebugData& DebugData)
    -> void
{
    auto DebugLine = DebugData.GetNodeName(this);
    DebugLine += TEXT("(");
    AddDebugNodeData(DebugLine);
    DebugLine += ck::Format_UE(TEXT(" Placed: {} Target: {})"), PlacedBone.BoneName, TargetBone.BoneName);
    DebugData.AddDebugItem(DebugLine);

    ComponentPose.GatherDebugData(DebugData);
}

auto
    FCk_AnimNode_Hands_GlovePlacement::
    EvaluateSkeletalControl_AnyThread(
        FComponentSpacePoseContext& Output,
        TArray<FBoneTransform>& OutBoneTransforms)
    -> void
{
    // Target is runtime data from the game: a bad one leaves the glove on its incoming pose.
    const auto IsTargetValid = ck::hands::Get_IsPlacementTargetValid(Target);
    CK_ENSURE_IF_NOT(IsTargetValid, TEXT("Glove Placement rejected a non-finite or unnormalized Target [{}] for [{}]"),
        Target, TargetBone.BoneName)
    { return; }

    const auto& BoneContainer = Output.Pose.GetPose().GetBoneContainer();
    const auto PlacedIndex = PlacedBone.GetCompactPoseIndex(BoneContainer);
    const auto TargetIndex = TargetBone.GetCompactPoseIndex(BoneContainer);

    const auto Placed = ck::hands::Get_GlovePlacement(
        Output.Pose.GetComponentSpaceTransform(PlacedIndex),
        Output.Pose.GetComponentSpaceTransform(TargetIndex),
        Target);

    OutBoneTransforms.Add(FBoneTransform{PlacedIndex, Placed});
}

auto
    FCk_AnimNode_Hands_GlovePlacement::
    IsValidToEvaluate(
        const USkeleton* Skeleton,
        const FBoneContainer& RequiredBones)
    -> bool
{
    return PlacedBone.IsValidToEvaluate(RequiredBones) && TargetBone.IsValidToEvaluate(RequiredBones);
}

auto
    FCk_AnimNode_Hands_GlovePlacement::
    InitializeBoneReferences(
        const FBoneContainer& RequiredBones)
    -> void
{
    PlacedBone.Initialize(RequiredBones);
    TargetBone.Initialize(RequiredBones);
}

// --------------------------------------------------------------------------------------------------------------------
