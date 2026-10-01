#include "CkHands_AnimGraphNode_GlovePlacement.h"

#include "CkCore/Validation/CkIsValid.h"

#include <Animation/Skeleton.h>
#include <Kismet2/CompilerResultsLog.h>

#define LOCTEXT_NAMESPACE "CkHandsEditor"

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_animgraphnode_gloveplacement
{
    auto
        DoGet_IsDescendant(
            const FReferenceSkeleton& InRefSkeleton,
            int32 InBoneIndex,
            int32 InAncestorIndex)
        -> bool
    {
        auto Ancestor = InRefSkeleton.GetParentIndex(InBoneIndex);
        while (Ancestor != INDEX_NONE && Ancestor != InAncestorIndex)
        { Ancestor = InRefSkeleton.GetParentIndex(Ancestor); }

        return Ancestor == InAncestorIndex;
    }
}

// --------------------------------------------------------------------------------------------------------------------

auto
    UCk_AnimGraphNode_Hands_GlovePlacement::
    GetNodeTitle(
        ENodeTitleType::Type TitleType) const
    -> FText
{
    if (TitleType == ENodeTitleType::ListView || TitleType == ENodeTitleType::MenuTitle || Node.TargetBone.BoneName.IsNone())
    { return GetControllerDescription(); }

    return FText::Format(LOCTEXT("GlovePlacement_Title", "{0}\n{1} -> Target"),
        GetControllerDescription(), FText::FromName(Node.TargetBone.BoneName));
}

auto
    UCk_AnimGraphNode_Hands_GlovePlacement::
    GetTooltipText() const
    -> FText
{
    return LOCTEXT("GlovePlacement_Tooltip",
        "Moves a floating hand rigidly by its root bone so that its target bone (e.g. a grip bone) lands on Target, "
        "in component space.");
}

auto
    UCk_AnimGraphNode_Hands_GlovePlacement::
    GetControllerDescription() const
    -> FText
{
    return LOCTEXT("GlovePlacement_Description", "Glove Placement (Ck Hands)");
}

auto
    UCk_AnimGraphNode_Hands_GlovePlacement::
    ValidateAnimNodeDuringCompilation(
        USkeleton* ForSkeleton,
        FCompilerResultsLog& MessageLog)
    -> void
{
    Super::ValidateAnimNodeDuringCompilation(ForSkeleton, MessageLog);

    if (ck::Is_NOT_Valid(ForSkeleton))
    { return; }

    const auto& RefSkeleton = ForSkeleton->GetReferenceSkeleton();
    const auto PlacedIndex = RefSkeleton.FindBoneIndex(Node.PlacedBone.BoneName);
    const auto TargetIndex = RefSkeleton.FindBoneIndex(Node.TargetBone.BoneName);

    if (PlacedIndex == INDEX_NONE)
    {
        MessageLog.Error(*LOCTEXT("GlovePlacement_NoPlaced", "@@ - Placed Bone is not set or not in the skeleton").ToString(), this);
        return;
    }

    if (TargetIndex == INDEX_NONE)
    {
        MessageLog.Error(*LOCTEXT("GlovePlacement_NoTarget", "@@ - Target Bone is not set or not in the skeleton").ToString(), this);
        return;
    }

    if (NOT ck_hands_animgraphnode_gloveplacement::DoGet_IsDescendant(RefSkeleton, TargetIndex, PlacedIndex))
    {
        MessageLog.Error(*LOCTEXT("GlovePlacement_NotDescendant", "@@ - Target Bone must be a descendant of Placed Bone").ToString(), this);
    }
}

auto
    UCk_AnimGraphNode_Hands_GlovePlacement::
    GetNode() const
    -> const FAnimNode_SkeletalControlBase*
{
    return &Node;
}

// --------------------------------------------------------------------------------------------------------------------

#undef LOCTEXT_NAMESPACE
