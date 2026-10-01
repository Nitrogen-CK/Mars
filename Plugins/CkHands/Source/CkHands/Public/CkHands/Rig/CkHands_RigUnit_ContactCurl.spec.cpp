#include "CkHands/Rig/CkHands_RigUnit_ContactCurl.h"

#include "CkHands/CkHands_Kernel.h"
#include "CkHands/CkHands_UnitTest_Common.h"

#include "CkCore/Ensure/CkEnsure_Utils.h"
#include "CkCore/Format/CkFormat.h"

#include "Misc/AutomationTest.h"

#include <Rigs/RigHierarchy.h>
#include <Rigs/RigHierarchyController.h>
#include <RigVMCore/RigVMExecuteContext.h>
#include <UObject/StrongObjectPtr.h>
#include <Units/RigUnitContext.h>

#if WITH_DEV_AUTOMATION_TESTS

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_rig_unit_contact_curl_spec
{
    constexpr auto kDeltaSeconds = 1.0f / 60.0f;
    constexpr auto kSegmentOffset = 4.0;

    // hand -> digit_01 -> digit_02 -> digit_03, each digit bone 4 cm along its parent's +X at rest. The incoming pose
    // bends every digit joint 60 degrees about -Z, so the digit curls toward -Y.
    struct FDigitRig
    {
        TStrongObjectPtr<URigHierarchy> _Hierarchy;
        TArray<FRigElementKey> _Items;
        TArray<FTransform> _Rest;
        TArray<FTransform> _Pose;
    };

    auto
        Make_DigitRig()
        -> FDigitRig
    {
        auto Rig = FDigitRig{};
        Rig._Hierarchy = TStrongObjectPtr<URigHierarchy>{NewObject<URigHierarchy>()};

        auto* Controller = Rig._Hierarchy->GetController(true);
        constexpr auto TransformInGlobal = false;
        auto Parent = Controller->AddBone(TEXT("hand"), FRigElementKey{}, FTransform::Identity, TransformInGlobal);

        const auto Bend = FQuat{FVector::UpVector, FMath::DegreesToRadians(-60.0)};
        for (const auto* BoneName : {TEXT("digit_01"), TEXT("digit_02"), TEXT("digit_03")})
        {
            const auto Rest = FTransform{FVector{kSegmentOffset, 0.0, 0.0}};
            Parent = Controller->AddBone(BoneName, Parent, Rest, TransformInGlobal);

            Rig._Items.Add(Parent);
            Rig._Rest.Add(Rest);
            Rig._Pose.Add(FTransform{Bend, Rest.GetTranslation()});
        }
        return Rig;
    }

    auto
        Make_ShapeInThePath()
        -> FCk_Hands_ContactShape
    {
        return FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Sphere, FTransform{FVector{9.0, -5.0, 0.0}}}.Set_Radius(2.0f);
    }

    auto
        Make_Unit(
            const FDigitRig& InRig,
            const FCk_Hands_ContactShape& InShape,
            float InInterpSpeed)
        -> FCk_RigUnit_Hands_ContactCurl
    {
        auto Unit = FCk_RigUnit_Hands_ContactCurl{};
        Unit.Items = InRig._Items;
        Unit.Shape = InShape;
        Unit.InterpSpeed = InInterpSpeed;
        return Unit;
    }

    // A rig re-evaluates its forward solve from the incoming animation pose every frame.
    auto
        Set_IncomingPose(
            const FDigitRig& InRig)
        -> void
    {
        for (auto Index = 0; Index < InRig._Items.Num(); ++Index)
        { InRig._Hierarchy->SetLocalTransform(InRig._Hierarchy->GetIndex(InRig._Items[Index]), InRig._Pose[Index]); }
    }

    auto
        Run_Unit(
            FCk_RigUnit_Hands_ContactCurl& InOutUnit,
            URigHierarchy* InHierarchy,
            float InDeltaSeconds)
        -> void
    {
        auto ExtendedContext = FRigVMExtendedExecuteContext{FControlRigExecuteContext::StaticStruct()};
        auto& Context = ExtendedContext.GetPublicData<FControlRigExecuteContext>();
        Context.Hierarchy = InHierarchy;
        Context.SetDeltaTime(InDeltaSeconds);
        InOutUnit.Execute(Context);
    }

    auto
        Run_Frame(
            FCk_RigUnit_Hands_ContactCurl& InOutUnit,
            const FDigitRig& InRig)
        -> void
    {
        Set_IncomingPose(InRig);
        Run_Unit(InOutUnit, InRig._Hierarchy.Get(), kDeltaSeconds);
    }

    auto
        Get_SolvedCurl(
            const FDigitRig& InRig,
            const FCk_Hands_ContactShape& InShape)
        -> float
    {
        return ck::hands::Solve_DigitCurl(InShape, FTransform::Identity, InRig._Rest, InRig._Pose, FCk_Hands_DigitContactSettings{});
    }

    auto
        Get_IsLocalRotationAt(
            const FDigitRig& InRig,
            float InCurl)
        -> bool
    {
        for (auto Index = 0; Index < InRig._Items.Num(); ++Index)
        {
            const auto Local = InRig._Hierarchy->GetLocalTransform(InRig._Hierarchy->GetIndex(InRig._Items[Index]));
            const auto Expected = FQuat::Slerp(InRig._Rest[Index].GetRotation(), InRig._Pose[Index].GetRotation(), InCurl);
            if (NOT Local.GetRotation().Equals(Expected, 1.0e-4) || NOT Local.GetTranslation().Equals(InRig._Pose[Index].GetTranslation(), 1.0e-4))
            { return false; }
        }
        return true;
    }

    auto
        Get_MinDistanceToDigit(
            const FDigitRig& InRig,
            const FCk_Hands_ContactShape& InShape,
            float InTipLengthRatio)
        -> double
    {
        constexpr auto PointsPerSegment = 32;

        auto Joints = TArray<FTransform>{};
        for (const auto& Item : InRig._Items)
        { Joints.Add(InRig._Hierarchy->GetGlobalTransform(InRig._Hierarchy->GetIndex(Item))); }

        auto Ends = TArray<FVector>{};
        for (const auto& Joint : Joints)
        { Ends.Add(Joint.GetLocation()); }
        Ends.Add(Joints.Last().TransformPosition(InRig._Pose.Last().GetTranslation() * InTipLengthRatio));

        auto MinDistance = TNumericLimits<double>::Max();
        for (auto End = 1; End < Ends.Num(); ++End)
        {
            for (auto Point = 0; Point <= PointsPerSegment; ++Point)
            {
                const auto Location = FMath::Lerp(Ends[End - 1], Ends[End], static_cast<double>(Point) / PointsPerSegment);
                MinDistance = FMath::Min(MinDistance, ck::hands::Get_SignedDistance(InShape, Location));
            }
        }
        return MinDistance;
    }
}

using ck::hands::tests::kCkUnitTestFlags;

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_NoShapeKeepsIncomingPose,
    "CkHands.RigUnit.ContactCurl_NoShapeKeepsIncomingPose",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_NoShapeKeepsIncomingPose::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    const auto Rig = Make_DigitRig();
    auto Unit = Make_Unit(Rig, FCk_Hands_ContactShape{}, 18.0f);

    constexpr auto SettleFrames = 30;
    for (auto Frame = 0; Frame < SettleFrames; ++Frame)
    { Run_Frame(Unit, Rig); }

    TestEqual(TEXT("Curl output is the full curl"), Unit.Curl, 1.0f);
    TestTrue(TEXT("every digit bone keeps its incoming pose"), Get_IsLocalRotationAt(Rig, 1.0f));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_ShapeInPathStopsWithoutPenetrating,
    "CkHands.RigUnit.ContactCurl_ShapeInPathStopsWithoutPenetrating",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_ShapeInPathStopsWithoutPenetrating::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    const auto Rig = Make_DigitRig();
    const auto Shape = Make_ShapeInThePath();
    auto Unit = Make_Unit(Rig, Shape, 0.0f);

    Run_Frame(Unit, Rig);

    TestTrue(*ck::Format_UE(TEXT("the curl stops strictly partway (got [{}])"), Unit.Curl), Unit.Curl > 0.0f && Unit.Curl < 1.0f);
    TestEqual(TEXT("the node curls as far as the solver allows"), Unit.Curl, Get_SolvedCurl(Rig, Shape), 1.0e-6f);
    TestTrue(TEXT("every digit bone is written at that curl"), Get_IsLocalRotationAt(Rig, Unit.Curl));

    const auto MinDistance = Get_MinDistanceToDigit(Rig, Shape, Unit.Settings.Get_TipLengthRatio());
    TestTrue(*ck::Format_UE(TEXT("the digit does not penetrate the shape (min distance [{}])"), MinDistance), MinDistance > 0.0);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_TooFewItemsWritesNothing,
    "CkHands.RigUnit.ContactCurl_TooFewItemsWritesNothing",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_TooFewItemsWritesNothing::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    const auto Rig = Make_DigitRig();
    auto Unit = Make_Unit(Rig, Make_ShapeInThePath(), 0.0f);
    Unit.Items = TArray<FRigElementKey>{Rig._Items[0]};
    Unit.Curl = -1.0f;

    Run_Frame(Unit, Rig);

    TestTrue(TEXT("the digit keeps its incoming pose although the shape is in its path"), Get_IsLocalRotationAt(Rig, 1.0f));
    TestEqual(TEXT("the Curl output is not written"), Unit.Curl, -1.0f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_MissingItemWritesNothing,
    "CkHands.RigUnit.ContactCurl_MissingItemWritesNothing",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_MissingItemWritesNothing::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    const auto Rig = Make_DigitRig();
    auto Unit = Make_Unit(Rig, Make_ShapeInThePath(), 0.0f);
    Unit.Items.Last() = FRigElementKey{TEXT("not_in_the_rig"), ERigElementType::Bone};
    Unit.Curl = -1.0f;

    Run_Frame(Unit, Rig);

    TestTrue(TEXT("the digit keeps its incoming pose although the shape is in its path"), Get_IsLocalRotationAt(Rig, 1.0f));
    TestEqual(TEXT("the Curl output is not written"), Unit.Curl, -1.0f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_EasingConverges,
    "CkHands.RigUnit.ContactCurl_EasingConverges",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_EasingConverges::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    constexpr auto InterpSpeed = 18.0f;
    const auto Rig = Make_DigitRig();
    const auto Shape = Make_ShapeInThePath();
    const auto Solved = Get_SolvedCurl(Rig, Shape);

    auto Unit = Make_Unit(Rig, FCk_Hands_ContactShape{}, InterpSpeed);
    Run_Frame(Unit, Rig);
    TestEqual(TEXT("the first frame snaps to the solved curl"), Unit.Curl, 1.0f);

    Unit.Shape = Shape;
    Run_Frame(Unit, Rig);

    const auto Expected = 1.0f + (Solved - 1.0f) * (1.0f - FMath::Exp(-InterpSpeed * kDeltaSeconds));
    TestEqual(TEXT("one frame later the curl has moved by the exponential ease"), Unit.Curl, Expected, 1.0e-5f);
    TestTrue(TEXT("and is still between where it was and where it is going"), Unit.Curl > Solved && Unit.Curl < 1.0f);
    TestTrue(TEXT("the digit is written at the eased curl"), Get_IsLocalRotationAt(Rig, Unit.Curl));

    constexpr auto SettleFrames = 240;
    for (auto Frame = 0; Frame < SettleFrames; ++Frame)
    { Run_Frame(Unit, Rig); }

    TestEqual(TEXT("the curl converges on the solved curl"), Unit.Curl, Solved, 1.0e-4f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_ZeroInterpSpeedSnaps,
    "CkHands.RigUnit.ContactCurl_ZeroInterpSpeedSnaps",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_ZeroInterpSpeedSnaps::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    const auto Rig = Make_DigitRig();
    const auto Shape = Make_ShapeInThePath();

    auto Unit = Make_Unit(Rig, FCk_Hands_ContactShape{}, 0.0f);
    Run_Frame(Unit, Rig);
    TestEqual(TEXT("no shape: the full curl"), Unit.Curl, 1.0f);

    Unit.Shape = Shape;
    Run_Frame(Unit, Rig);
    TestEqual(TEXT("the next frame snaps straight to the solved curl"), Unit.Curl, Get_SolvedCurl(Rig, Shape), 1.0e-6f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_InvalidSettingsKeepIncomingPose,
    "CkHands.RigUnit.ContactCurl_InvalidSettingsKeepIncomingPose",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_InvalidSettingsKeepIncomingPose::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    const auto Rig = Make_DigitRig();
    auto Unit = Make_Unit(Rig, Make_ShapeInThePath(), 0.0f);
    Unit.Settings = FCk_Hands_DigitContactSettings{}.Set_Radius(0.0f);

    const auto EnsureCountBefore = UCk_Utils_Ensure_UE::Get_EnsureCount();
    Run_Frame(Unit, Rig);

    TestEqual(TEXT("invalid settings are authoring state: no ensure"), UCk_Utils_Ensure_UE::Get_EnsureCount(), EnsureCountBefore);
    TestEqual(TEXT("the solve is treated as the full curl"), Unit.Curl, 1.0f);
    TestTrue(TEXT("the digit keeps its incoming pose although the shape is in its path"), Get_IsLocalRotationAt(Rig, 1.0f));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_RigUnitContactCurl_RejectsMissingHierarchy,
    "CkHands.RigUnit.ContactCurl_RejectsMissingHierarchy",
    kCkUnitTestFlags)

bool FCkTest_Hands_RigUnitContactCurl_RejectsMissingHierarchy::RunTest(const FString&)
{
    using namespace ck_hands_rig_unit_contact_curl_spec;

    const auto Rig = Make_DigitRig();
    auto Unit = Make_Unit(Rig, Make_ShapeInThePath(), 0.0f);
    Unit.Curl = -1.0f;

    // Suppressed only (-1): the ensure count is the enforceable assertion.
    AddExpectedError(TEXT("Contact Curl executed without a rig hierarchy"), EAutomationExpectedErrorFlags::Contains, -1);
    const auto EnsureCountBefore = UCk_Utils_Ensure_UE::Get_EnsureCount();

    Set_IncomingPose(Rig);
    Run_Unit(Unit, nullptr, kDeltaSeconds);

    TestEqual(TEXT("ensured exactly once"), UCk_Utils_Ensure_UE::Get_EnsureCount(), EnsureCountBefore + 1);
    TestEqual(TEXT("the Curl output is not written"), Unit.Curl, -1.0f);
    TestTrue(TEXT("the digit keeps its incoming pose"), Get_IsLocalRotationAt(Rig, 1.0f));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

#endif
