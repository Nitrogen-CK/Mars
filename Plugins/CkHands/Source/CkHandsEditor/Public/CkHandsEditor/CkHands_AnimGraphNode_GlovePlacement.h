#pragma once

#include "CkHands/AnimNode/CkHands_AnimNode_GlovePlacement.h"

#include <AnimGraphNode_SkeletalControlBase.h>

#include "CkHands_AnimGraphNode_GlovePlacement.generated.h"

// --------------------------------------------------------------------------------------------------------------------

UCLASS(meta = (Keywords = "Hand,Glove,Grip,Place,Floating"))
class CKHANDSEDITOR_API UCk_AnimGraphNode_Hands_GlovePlacement : public UAnimGraphNode_SkeletalControlBase
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, Category = "Settings")
    FCk_AnimNode_Hands_GlovePlacement Node;

public:
    auto
        GetNodeTitle(
            ENodeTitleType::Type TitleType) const
        -> FText override;

    auto
        GetTooltipText() const
        -> FText override;

protected:
    auto
        GetControllerDescription() const
        -> FText override;

    auto
        ValidateAnimNodeDuringCompilation(
            USkeleton* ForSkeleton,
            FCompilerResultsLog& MessageLog)
        -> void override;

    auto
        GetNode() const
        -> const FAnimNode_SkeletalControlBase* override;
};

// --------------------------------------------------------------------------------------------------------------------
