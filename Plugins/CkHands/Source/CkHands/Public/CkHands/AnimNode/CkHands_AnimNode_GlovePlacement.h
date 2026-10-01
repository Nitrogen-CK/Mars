#pragma once

#include <BoneContainer.h>
#include <BoneControllers/AnimNode_SkeletalControlBase.h>

#include "CkHands_AnimNode_GlovePlacement.generated.h"

// --------------------------------------------------------------------------------------------------------------------

/**
 * Places a floating hand so that one of its bones lands on a target, in component space: the hand moves rigidly by its
 * root bone (PlacedBone, e.g. lowerarm) so that TargetBone (e.g. a grip bone under the hand) ends up exactly at Target
 * (ck::hands::Get_GlovePlacement). The root-to-target offset is read from the incoming pose, so an animated wrist is
 * kept; Target's scale is ignored and PlacedBone keeps its own scale. TargetBone must be a descendant of PlacedBone
 * (checked when the anim blueprint compiles).
 */
USTRUCT(BlueprintInternalUseOnly)
struct CKHANDS_API FCk_AnimNode_Hands_GlovePlacement : public FAnimNode_SkeletalControlBase
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, Category = "Placement")
    FBoneReference PlacedBone;

    UPROPERTY(EditAnywhere, Category = "Placement")
    FBoneReference TargetBone;

    // Where TargetBone should be, in component space.
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Placement", meta = (PinShownByDefault))
    FTransform Target;

public:
    virtual auto
        GatherDebugData(
            FNodeDebugData& DebugData)
        -> void override;

    virtual auto
        EvaluateSkeletalControl_AnyThread(
            FComponentSpacePoseContext& Output,
            TArray<FBoneTransform>& OutBoneTransforms)
        -> void override;

    virtual auto
        IsValidToEvaluate(
            const USkeleton* Skeleton,
            const FBoneContainer& RequiredBones)
        -> bool override;

private:
    virtual auto
        InitializeBoneReferences(
            const FBoneContainer& RequiredBones)
        -> void override;
};

// --------------------------------------------------------------------------------------------------------------------
