#include "CkHands_RigUnit_ContactCurl.h"

#include "CkHands/CkHands_Kernel.h"

#include "CkCore/Ensure/CkEnsure.h"
#include "CkCore/Validation/CkIsValid.h"

#include <Units/RigUnitContext.h>

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_rig_unit_contact_curl
{
    using TransformsType = TArray<FTransform, TInlineAllocator<4>>;

    auto
        DoRefresh_Cache(
            TConstArrayView<FRigElementKey> InItems,
            const URigHierarchy& InHierarchy,
            TArray<FCachedRigElement>& InOutCache)
        -> bool
    {
        if (InOutCache.Num() != InItems.Num())
        {
            InOutCache.Reset();
            InOutCache.SetNum(InItems.Num());
        }

        auto AllFound = true;
        for (auto Index = 0; Index < InItems.Num(); ++Index)
        {
            if (NOT InOutCache[Index].UpdateCache(InItems[Index], &InHierarchy))
            { AllFound = false; }
        }
        return AllFound;
    }

    auto
        DoGet_FirstMissingItem(
            TConstArrayView<FRigElementKey> InItems,
            const TArray<FCachedRigElement>& InCache)
        -> FString
    {
        for (auto Index = 0; Index < InItems.Num(); ++Index)
        {
            if (NOT InCache[Index].IsValid())
            { return InItems[Index].ToString(); }
        }
        return {};
    }

    auto
        DoGet_EasedCurl(
            FCk_RigUnit_Hands_ContactCurl_WorkData& InOutWorkData,
            float InSolved,
            float InInterpSpeed,
            float InDeltaSeconds)
        -> float
    {
        if (NOT InOutWorkData.IsInitialized || InInterpSpeed <= 0.0f || InDeltaSeconds <= 0.0f)
        {
            InOutWorkData.Curl = InSolved;
            InOutWorkData.IsInitialized = true;
            return InOutWorkData.Curl;
        }

        const auto Alpha = 1.0f - FMath::Exp(-InInterpSpeed * InDeltaSeconds);
        InOutWorkData.Curl += (InSolved - InOutWorkData.Curl) * Alpha;
        return InOutWorkData.Curl;
    }
}

// --------------------------------------------------------------------------------------------------------------------

FCk_RigUnit_Hands_ContactCurl_Execute()
{
    DECLARE_SCOPE_HIERARCHICAL_COUNTER_RIGUNIT()

    auto* Hierarchy = ExecuteContext.Hierarchy;
    const auto HasHierarchy = ck::IsValid(Hierarchy);
    CK_ENSURE_IF_NOT(HasHierarchy, TEXT("Contact Curl executed without a rig hierarchy"))
    { return; }

    const auto HasChain = Items.Num() >= 2;
    if (NOT HasChain)
    {
        UE_CONTROLRIG_RIGUNIT_REPORT_WARNING(TEXT("%s"),
            *ck::Format_UE(TEXT("Contact Curl needs a digit chain of at least two items, got [{}]"), Items.Num()));
        return;
    }

    const auto IsChainInHierarchy = ck_hands_rig_unit_contact_curl::DoRefresh_Cache(Items, *Hierarchy, WorkData.CachedItems);
    if (NOT IsChainInHierarchy)
    {
        UE_CONTROLRIG_RIGUNIT_REPORT_WARNING(TEXT("%s"),
            *ck::Format_UE(TEXT("Contact Curl: item [{}] is not in the rig hierarchy"),
                ck_hands_rig_unit_contact_curl::DoGet_FirstMissingItem(Items, WorkData.CachedItems)));
        return;
    }

    auto Rest = ck_hands_rig_unit_contact_curl::TransformsType{};
    auto Pose = ck_hands_rig_unit_contact_curl::TransformsType{};
    for (const auto& Cached : WorkData.CachedItems)
    {
        Rest.Add(Hierarchy->GetInitialLocalTransform(Cached.GetIndex()));
        Pose.Add(Hierarchy->GetLocalTransform(Cached.GetIndex()));
    }

    const auto Solved = [&]() -> float
    {
        if (Shape.Get_Type() == ECk_Hands_ContactShapeType::None)
        { return 1.0f; }

        const auto IsSettingsValid = ck::hands::Get_IsSettingsValid(Settings);
        if (NOT IsSettingsValid)
        {
            UE_CONTROLRIG_RIGUNIT_REPORT_WARNING(TEXT("%s"), *ck::Format_UE(
                TEXT("Contact Curl: invalid Settings (Radius [{}] must be > 0, Max Search Steps [{}] >= 2, "
                     "Tip Length Ratio [{}] >= 0, all finite); the digit keeps its incoming pose"),
                Settings.Get_Radius(), Settings.Get_MaxSearchSteps(), Settings.Get_TipLengthRatio()));
            return 1.0f;
        }

        const auto ParentIndex = Hierarchy->GetFirstParent(WorkData.CachedItems[0].GetIndex());
        const auto Parent = ParentIndex == INDEX_NONE ? FTransform::Identity : Hierarchy->GetGlobalTransform(ParentIndex);
        return ck::hands::Solve_DigitCurl(Shape, Parent, Rest, Pose, Settings);
    }();

    Curl = ck_hands_rig_unit_contact_curl::DoGet_EasedCurl(WorkData, Solved, InterpSpeed, ExecuteContext.GetDeltaTime<float>());

    constexpr auto AffectChildren = true;
    for (auto Index = 0; Index < WorkData.CachedItems.Num(); ++Index)
    {
        auto Local = Pose[Index];
        Local.SetRotation(FQuat::Slerp(Rest[Index].GetRotation(), Pose[Index].GetRotation(), Curl));
        Hierarchy->SetLocalTransform(WorkData.CachedItems[Index].GetIndex(), Local, AffectChildren);
    }
}

// --------------------------------------------------------------------------------------------------------------------
