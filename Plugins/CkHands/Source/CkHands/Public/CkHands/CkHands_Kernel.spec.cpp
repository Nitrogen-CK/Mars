#include "CkHands/CkHands_Kernel.h"

#include "CkHands/CkHands_UnitTest_Common.h"

#include "CkCore/Ensure/CkEnsure_Utils.h"
#include "CkCore/Format/CkFormat.h"

#include "Misc/AutomationTest.h"

#include <limits>

#if WITH_DEV_AUTOMATION_TESTS

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_kernel_spec
{
    constexpr auto kDistanceTolerance = 1.0e-6;
    constexpr auto kSegmentLength = 4.0;
    constexpr auto kDensePointsPerSegment = 32;

    auto
        Make_Sphere(
            const FVector& InCenter,
            float InRadius)
        -> FCk_Hands_ContactShape
    {
        return FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Sphere, FTransform{InCenter}}.Set_Radius(InRadius);
    }

    auto
        Make_Box(
            const FTransform& InTransform,
            const FVector& InHalfExtents)
        -> FCk_Hands_ContactShape
    {
        return FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Box, InTransform}.Set_HalfExtents(InHalfExtents);
    }

    auto
        Make_Capsule(
            const FTransform& InTransform,
            float InHalfHeight,
            float InRadius)
        -> FCk_Hands_ContactShape
    {
        return FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Capsule, InTransform}
            .Set_HalfHeight(InHalfHeight)
            .Set_Radius(InRadius);
    }

    // A three-segment digit whose segments are offset by InTranslation from their parent, each bent by InBend.
    auto
        Make_Chain(
            const FVector& InTranslation,
            const FQuat& InBend)
        -> TArray<FTransform>
    {
        return {
            FTransform{InBend, InTranslation},
            FTransform{InBend, InTranslation},
            FTransform{InBend, InTranslation}};
    }

    auto
        Make_StraightChain()
        -> TArray<FTransform>
    {
        return Make_Chain(FVector{kSegmentLength, 0.0, 0.0}, FQuat::Identity);
    }

    // Every joint bends 60 degrees about -Z: the +X digit curls toward -Y and its tip rolls back under the root.
    auto
        Make_CurledChain()
        -> TArray<FTransform>
    {
        return Make_Chain(FVector{kSegmentLength, 0.0, 0.0}, FQuat{FVector::UpVector, FMath::DegreesToRadians(-60.0)});
    }

    // Only the last joint bends (90 degrees about Z, signed by InBendSign), so only the tip segment moves.
    auto
        Make_TipOnlyChain(
            double InTranslationX,
            double InBendSign)
        -> TArray<FTransform>
    {
        auto Chain = Make_Chain(FVector{InTranslationX, 0.0, 0.0}, FQuat::Identity);
        Chain.Last().SetRotation(FQuat{FVector::UpVector, InBendSign * FMath::DegreesToRadians(90.0)});
        return Chain;
    }

    auto
        Append_Line(
            const FVector& InStart,
            const FVector& InEnd,
            TArray<FVector>& OutPoints)
        -> void
    {
        for (auto Point = 0; Point <= kDensePointsPerSegment; ++Point)
        { OutPoints.Add(FMath::Lerp(InStart, InEnd, static_cast<double>(Point) / kDensePointsPerSegment)); }
    }

    // Densely sampled moving segments of the digit at InCurl, from the forward kinematics Solve_DigitCurl documents.
    auto
        Get_DigitPoints(
            const FTransform& InParent,
            const TArray<FTransform>& InRest,
            const TArray<FTransform>& InPose,
            float InTipLengthRatio,
            float InCurl)
        -> TArray<FVector>
    {
        auto Points = TArray<FVector>{};
        auto Joint = InParent;
        for (auto Segment = 0; Segment < InPose.Num(); ++Segment)
        {
            const auto Rotation = FQuat::Slerp(InRest[Segment].GetRotation(), InPose[Segment].GetRotation(), InCurl);
            const auto Next = FTransform{Rotation, InPose[Segment].GetTranslation(), InPose[Segment].GetScale3D()} * Joint;

            if (Segment > 0)
            { Append_Line(Joint.GetLocation(), Next.GetLocation(), Points); }

            Joint = Next;
        }
        Append_Line(Joint.GetLocation(), Joint.TransformPosition(InPose.Last().GetTranslation() * InTipLengthRatio), Points);
        return Points;
    }

    auto
        Get_MinSignedDistance(
            const FCk_Hands_ContactShape& InShape,
            const TArray<FVector>& InPoints)
        -> double
    {
        auto MinDistance = TNumericLimits<double>::Max();
        for (const auto& Point : InPoints)
        { MinDistance = FMath::Min(MinDistance, ck::hands::Get_SignedDistance(InShape, Point)); }
        return MinDistance;
    }

    // Ck ensures can reach more than one log sink and an ignored site logs nothing, so the log lines are only
    // suppressed (Occurrences -1) and the ensure COUNT is the enforceable assertion.
    auto
        Expect_RejectedWithFullCurl(
            FAutomationTestBase& InTest,
            const TCHAR* InWhat,
            TFunctionRef<float()> InSolve)
        -> void
    {
        constexpr auto IgnoreAllOccurrences = -1;
        InTest.AddExpectedError(TEXT("Solve_DigitCurl rejected"), EAutomationExpectedErrorFlags::Contains, IgnoreAllOccurrences);

        const auto EnsureCountBefore = UCk_Utils_Ensure_UE::Get_EnsureCount();
        const auto Curl = InSolve();

        InTest.TestEqual(*ck::Format_UE(TEXT("{}: ensured exactly once"), InWhat),
            UCk_Utils_Ensure_UE::Get_EnsureCount(), EnsureCountBefore + 1);
        InTest.TestEqual(*ck::Format_UE(TEXT("{}: recovers with the full curl"), InWhat), Curl, 1.0f);
    }
}

using ck::hands::tests::kCkUnitTestFlags;

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_SignedDistance_Sphere,
    "CkHands.Kernel.SignedDistance_Sphere",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_SignedDistance_Sphere::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Sphere = Make_Sphere(FVector{1.0, 2.0, 3.0}, 2.0f);
    TestEqual(TEXT("outside"), ck::hands::Get_SignedDistance(Sphere, FVector{6.0, 2.0, 3.0}), 3.0, kDistanceTolerance);
    TestEqual(TEXT("inside"), ck::hands::Get_SignedDistance(Sphere, FVector{1.5, 2.0, 3.0}), -1.5, kDistanceTolerance);
    TestEqual(TEXT("on the surface"), ck::hands::Get_SignedDistance(Sphere, FVector{1.0, 0.0, 3.0}), 0.0, kDistanceTolerance);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_SignedDistance_Box,
    "CkHands.Kernel.SignedDistance_Box",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_SignedDistance_Box::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Box = Make_Box(FTransform::Identity, FVector{1.0, 2.0, 3.0});
    TestEqual(TEXT("off a face"), ck::hands::Get_SignedDistance(Box, FVector{0.0, 5.0, 0.0}), 3.0, kDistanceTolerance);
    TestEqual(TEXT("off an edge"), ck::hands::Get_SignedDistance(Box, FVector{2.0, 3.0, 0.0}), FMath::Sqrt(2.0), kDistanceTolerance);
    TestEqual(TEXT("inside, nearest face is X"), ck::hands::Get_SignedDistance(Box, FVector::ZeroVector), -1.0, kDistanceTolerance);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_SignedDistance_CapsuleAlongLocalZ,
    "CkHands.Kernel.SignedDistance_CapsuleAlongLocalZ",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_SignedDistance_CapsuleAlongLocalZ::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Capsule = Make_Capsule(FTransform::Identity, 5.0f, 1.0f);
    TestEqual(TEXT("beside the cylinder section"), ck::hands::Get_SignedDistance(Capsule, FVector{4.0, 0.0, 3.0}), 3.0, kDistanceTolerance);
    TestEqual(TEXT("past the +Z cap"), ck::hands::Get_SignedDistance(Capsule, FVector{0.0, 0.0, 8.0}), 2.0, kDistanceTolerance);
    TestEqual(TEXT("past the -Z cap"), ck::hands::Get_SignedDistance(Capsule, FVector{0.0, 0.0, -8.0}), 2.0, kDistanceTolerance);
    TestEqual(TEXT("local X is across the capsule, not along it"), ck::hands::Get_SignedDistance(Capsule, FVector{8.0, 0.0, 0.0}), 7.0, kDistanceTolerance);
    TestEqual(TEXT("inside"), ck::hands::Get_SignedDistance(Capsule, FVector{0.0, 0.0, 4.0}), -1.0, kDistanceTolerance);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_SignedDistance_RotatedTranslatedAndScaleIgnored,
    "CkHands.Kernel.SignedDistance_RotatedTranslatedAndScaleIgnored",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_SignedDistance_RotatedTranslatedAndScaleIgnored::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    // 90 degrees about Z: local +X points along world +Y, local +Y along world -X.
    const auto Transform = FTransform{FQuat{FVector::UpVector, FMath::DegreesToRadians(90.0)}, FVector{10.0, 0.0, 0.0}};
    const auto Box = Make_Box(Transform, FVector{1.0, 2.0, 3.0});
    TestEqual(TEXT("off the local +Y face"), ck::hands::Get_SignedDistance(Box, FVector{5.0, 0.0, 0.0}), 3.0, kDistanceTolerance);
    TestEqual(TEXT("off the local +X face"), ck::hands::Get_SignedDistance(Box, FVector{10.0, 1.5, 0.0}), 0.5, kDistanceTolerance);

    auto ScaledTransform = Transform;
    ScaledTransform.SetScale3D(FVector{10.0, 3.0, 0.5});
    const auto ScaledBox = Make_Box(ScaledTransform, FVector{1.0, 2.0, 3.0});
    TestEqual(TEXT("scale is ignored"), ck::hands::Get_SignedDistance(ScaledBox, FVector{5.0, 0.0, 0.0}), 3.0, kDistanceTolerance);

    // Rotated so local Z (the capsule axis) lies along world -Y.
    const auto Capsule = Make_Capsule(FTransform{FQuat{FVector::ForwardVector, FMath::DegreesToRadians(90.0)}, FVector{0.0, 0.0, 10.0}}, 5.0f, 1.0f);
    TestEqual(TEXT("rotated capsule: along its axis"), ck::hands::Get_SignedDistance(Capsule, FVector{0.0, -8.0, 10.0}), 2.0, kDistanceTolerance);
    TestEqual(TEXT("rotated capsule: across its axis"), ck::hands::Get_SignedDistance(Capsule, FVector{0.0, 0.0, 14.0}), 3.0, kDistanceTolerance);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_SignedDistance_None,
    "CkHands.Kernel.SignedDistance_None",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_SignedDistance_None::RunTest(const FString&)
{
    TestEqual(TEXT("None is infinitely far"),
        ck::hands::Get_SignedDistance(FCk_Hands_ContactShape{}, FVector::ZeroVector), TNumericLimits<double>::Max());

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_IsShapeValid_Rejections,
    "CkHands.Kernel.IsShapeValid_Rejections",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_IsShapeValid_Rejections::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto NaN = std::numeric_limits<double>::quiet_NaN();
    const auto Infinity = std::numeric_limits<float>::infinity();

    TestTrue(TEXT("a default (None) shape is valid"), ck::hands::Get_IsShapeValid(FCk_Hands_ContactShape{}));
    TestTrue(TEXT("a sphere is valid"), ck::hands::Get_IsShapeValid(Make_Sphere(FVector::ZeroVector, 1.0f)));
    TestTrue(TEXT("a zero-size box is valid"), ck::hands::Get_IsShapeValid(Make_Box(FTransform::Identity, FVector::ZeroVector)));

    TestFalse(TEXT("negative sphere radius"), ck::hands::Get_IsShapeValid(Make_Sphere(FVector::ZeroVector, -1.0f)));
    TestFalse(TEXT("infinite sphere radius"), ck::hands::Get_IsShapeValid(Make_Sphere(FVector::ZeroVector, Infinity)));
    TestFalse(TEXT("NaN box half extent"), ck::hands::Get_IsShapeValid(Make_Box(FTransform::Identity, FVector{1.0, NaN, 1.0})));
    TestFalse(TEXT("negative box half extent"), ck::hands::Get_IsShapeValid(Make_Box(FTransform::Identity, FVector{1.0, 1.0, -1.0})));
    TestFalse(TEXT("negative capsule half height"), ck::hands::Get_IsShapeValid(Make_Capsule(FTransform::Identity, -1.0f, 1.0f)));
    TestFalse(TEXT("negative capsule radius"), ck::hands::Get_IsShapeValid(Make_Capsule(FTransform::Identity, 1.0f, -1.0f)));
    TestFalse(TEXT("non-finite transform"), ck::hands::Get_IsShapeValid(Make_Sphere(FVector{NaN, 0.0, 0.0}, 1.0f)));

    auto Unnormalized = FTransform::Identity;
    Unnormalized.SetRotation(FQuat{0.0, 0.0, 0.0, 2.0});
    TestFalse(TEXT("non-normalized rotation"), ck::hands::Get_IsShapeValid(Make_Sphere(FVector::ZeroVector, 1.0f).Set_Transform(Unnormalized)));

    TestTrue(TEXT("dimensions the type does not read are not checked"),
        ck::hands::Get_IsShapeValid(Make_Sphere(FVector::ZeroVector, 1.0f).Set_HalfHeight(-1.0f).Set_HalfExtents(FVector{-1.0})));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_IsSettingsValid_Rejections,
    "CkHands.Kernel.IsSettingsValid_Rejections",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_IsSettingsValid_Rejections::RunTest(const FString&)
{
    const auto NaN = std::numeric_limits<float>::quiet_NaN();
    const auto Infinity = std::numeric_limits<float>::infinity();

    TestTrue(TEXT("the defaults are valid"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}));
    TestTrue(TEXT("2 search steps and a zero tip ratio are valid"),
        ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{0.01f, 2, 0.0f}));

    TestFalse(TEXT("zero radius"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}.Set_Radius(0.0f)));
    TestFalse(TEXT("negative radius"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}.Set_Radius(-1.0f)));
    TestFalse(TEXT("NaN radius"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}.Set_Radius(NaN)));
    TestFalse(TEXT("infinite radius"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}.Set_Radius(Infinity)));
    TestFalse(TEXT("fewer than 2 search steps"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}.Set_MaxSearchSteps(1)));
    TestFalse(TEXT("negative tip length ratio"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}.Set_TipLengthRatio(-0.1f)));
    TestFalse(TEXT("infinite tip length ratio"), ck::hands::Get_IsSettingsValid(FCk_Hands_DigitContactSettings{}.Set_TipLengthRatio(Infinity)));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_ShapeInSpace_RoundTrip,
    "CkHands.Kernel.ShapeInSpace_RoundTrip",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_ShapeInSpace_RoundTrip::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Shape = Make_Capsule(FTransform{FRotator{20.0, 35.0, -10.0}, FVector{5.0, -3.0, 8.0}}, 4.0f, 1.5f);
    const auto Space = FTransform{FRotator{-40.0, 110.0, 25.0}, FVector{100.0, -50.0, 30.0}, FVector{2.0}};
    const auto InSpace = ck::hands::Get_ShapeInSpace(Shape, Space);

    TestTrue(TEXT("type is kept"), InSpace.Get_Type() == Shape.Get_Type());
    TestEqual(TEXT("radius is kept"), InSpace.Get_Radius(), Shape.Get_Radius());
    TestEqual(TEXT("half height is kept"), InSpace.Get_HalfHeight(), Shape.Get_HalfHeight());

    const auto Points = TArray<FVector>{
        FVector{5.0, -3.0, 8.0},
        FVector{12.0, 4.0, -6.0},
        FVector{-30.0, 2.0, 15.0},
        FVector{6.0, -2.0, 11.0}};

    for (const auto& Point : Points)
    {
        TestEqual(*ck::Format_UE(TEXT("distance to [{}] survives the change of space"), Point),
            ck::hands::Get_SignedDistance(InSpace, Space.InverseTransformPositionNoScale(Point)),
            ck::hands::Get_SignedDistance(Shape, Point),
            1.0e-6);
    }

    const auto RigidSpace = FTransform{Space.GetRotation(), Space.GetTranslation()};
    const auto Back = ck::hands::Get_ShapeInSpace(InSpace, RigidSpace.Inverse());
    TestTrue(TEXT("re-expressing in the inverse of the rigid space returns the original transform"),
        Back.Get_Transform().Equals(Shape.Get_Transform(), 1.0e-6));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_NoneShapeIsFullCurl,
    "CkHands.Kernel.Solve_NoneShapeIsFullCurl",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_NoneShapeIsFullCurl::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Settings = FCk_Hands_DigitContactSettings{};
    const auto EnsureCountBefore = UCk_Utils_Ensure_UE::Get_EnsureCount();

    TestEqual(TEXT("None: the full pose"),
        ck::hands::Solve_DigitCurl(FCk_Hands_ContactShape{}, FTransform::Identity, Make_StraightChain(), Make_CurledChain(), Settings), 1.0f);
    TestEqual(TEXT("None is a fast path, not a contract check: an empty chain does not ensure"),
        ck::hands::Solve_DigitCurl(FCk_Hands_ContactShape{}, FTransform::Identity, TArray<FTransform>{}, TArray<FTransform>{}, Settings), 1.0f);
    TestEqual(TEXT("no ensure"), UCk_Utils_Ensure_UE::Get_EnsureCount(), EnsureCountBefore);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_OutOfReachIsFullCurl,
    "CkHands.Kernel.Solve_OutOfReachIsFullCurl",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_OutOfReachIsFullCurl::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto FarAway = Make_Sphere(FVector{0.0, 0.0, 100.0}, 3.0f);
    TestEqual(TEXT("a shape out of reach: the full pose"),
        ck::hands::Solve_DigitCurl(FarAway, FTransform::Identity, Make_StraightChain(), Make_CurledChain(), FCk_Hands_DigitContactSettings{}), 1.0f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_ShapeInPathStopsWithoutPenetrating,
    "CkHands.Kernel.Solve_ShapeInPathStopsWithoutPenetrating",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_ShapeInPathStopsWithoutPenetrating::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Rest = Make_StraightChain();
    const auto Pose = Make_CurledChain();
    const auto Settings = FCk_Hands_DigitContactSettings{};
    const auto InThePath = Make_Sphere(FVector{9.0, -5.0, 0.0}, 2.0f);

    const auto RestPoints = Get_DigitPoints(FTransform::Identity, Rest, Pose, Settings.Get_TipLengthRatio(), 0.0f);
    TestTrue(TEXT("precondition: the shape is clear of the digit at rest"), Get_MinSignedDistance(InThePath, RestPoints) >= Settings.Get_Radius());

    const auto Curl = ck::hands::Solve_DigitCurl(InThePath, FTransform::Identity, Rest, Pose, Settings);
    TestTrue(*ck::Format_UE(TEXT("the curl stops strictly partway (got [{}])"), Curl), Curl > 0.0f && Curl < 1.0f);

    const auto Points = Get_DigitPoints(FTransform::Identity, Rest, Pose, Settings.Get_TipLengthRatio(), Curl);
    const auto MinDistance = Get_MinSignedDistance(InThePath, Points);
    TestTrue(*ck::Format_UE(TEXT("the digit does not penetrate the shape at the returned curl (min distance [{}])"), MinDistance), MinDistance > 0.0);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_TouchingAtRestOnlyNewContactStops,
    "CkHands.Kernel.Solve_TouchingAtRestOnlyNewContactStops",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_TouchingAtRestOnlyNewContactStops::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Rest = Make_StraightChain();
    const auto Pose = Make_CurledChain();
    const auto Settings = FCk_Hands_DigitContactSettings{};
    const auto Radius = static_cast<double>(Settings.Get_Radius());

    // Around the first joint, like a handle through the palm: the first segment's samples nearest the joint start (and
    // stay) inside it while every other sample starts outside, and the curl swings those away from it.
    const auto AroundFirstJoint = Make_Sphere(FVector{kSegmentLength, 0.0, 0.0}, 2.0f);

    const auto RestPoints = Get_DigitPoints(FTransform::Identity, Rest, Pose, Settings.Get_TipLengthRatio(), 0.0f);
    const auto StartsInside = RestPoints.FilterByPredicate([&](const FVector& InPoint)
    {
        return ck::hands::Get_SignedDistance(AroundFirstJoint, InPoint) < Radius;
    });
    TestTrue(TEXT("precondition: some of the digit starts within Radius of the shape"), StartsInside.Num() > 0);
    TestTrue(TEXT("precondition: some of the digit starts clear of the shape"), StartsInside.Num() < RestPoints.Num());

    TestEqual(TEXT("contact that already existed at rest never stops the curl"),
        ck::hands::Solve_DigitCurl(AroundFirstJoint, FTransform::Identity, Rest, Pose, Settings), 1.0f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_ThinShapeIsNotTunnelled,
    "CkHands.Kernel.Solve_ThinShapeIsNotTunnelled",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_ThinShapeIsNotTunnelled::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    // Only the tip segment moves: it sweeps a quarter circle about the last joint (12, 0, 0), from +X toward -Y, with
    // radius 4 * TipLengthRatio. A thin plate stands across that sweep at a bearing halfway between two of the curls an
    // 8-step uniform search would test, so such a search steps right over it.
    const auto Rest = Make_TipOnlyChain(kSegmentLength, 0.0);
    const auto Pose = Make_TipOnlyChain(kSegmentLength, -1.0);
    const auto Settings = FCk_Hands_DigitContactSettings{0.25f, 64, 0.9f};
    const auto Radius = static_cast<double>(Settings.Get_Radius());

    const auto LastJoint = FVector{3.0 * kSegmentLength, 0.0, 0.0};
    const auto TipLength = kSegmentLength * Settings.Get_TipLengthRatio();
    const auto PlateBearing = FMath::DegreesToRadians(90.0 * 4.5 / 8.0);
    const auto PlateDistance = 3.4;
    const auto Plate = Make_Box(
        FTransform{FQuat{FVector::UpVector, -PlateBearing}, LastJoint + PlateDistance * FVector{FMath::Cos(PlateBearing), -FMath::Sin(PlateBearing), 0.0}},
        FVector{0.15, 0.05, 2.0});

    const auto Get_TipPoint = [&](double InCurl, double InAlongTip) -> FVector
    {
        const auto Bearing = FMath::DegreesToRadians(90.0 * InCurl);
        return LastJoint + InAlongTip * FVector{FMath::Cos(Bearing), -FMath::Sin(Bearing), 0.0};
    };

    constexpr auto CoarseSteps = 8;
    const auto SamplesAlongTip = FMath::CeilToInt32(TipLength / Radius);
    auto CoarseSearchMisses = true;
    for (auto Step = 0; Step <= CoarseSteps; ++Step)
    {
        for (auto Sample = 1; Sample <= SamplesAlongTip; ++Sample)
        {
            const auto Point = Get_TipPoint(static_cast<double>(Step) / CoarseSteps, TipLength * Sample / SamplesAlongTip);
            if (ck::hands::Get_SignedDistance(Plate, Point) < Radius)
            { CoarseSearchMisses = false; }
        }
    }
    TestTrue(TEXT("precondition: an 8-step uniform search with the same samples never touches the plate"), CoarseSearchMisses);

    const auto Curl = ck::hands::Solve_DigitCurl(Plate, FTransform::Identity, Rest, Pose, Settings);
    TestTrue(*ck::Format_UE(TEXT("the tip stops before the plate (got [{}])"), Curl), Curl > 0.45f && Curl < 4.5f / 8.0f);

    const auto Points = Get_DigitPoints(FTransform::Identity, Rest, Pose, Settings.Get_TipLengthRatio(), Curl);
    const auto MinDistance = Get_MinSignedDistance(Plate, Points);
    TestTrue(*ck::Format_UE(TEXT("the digit does not penetrate the plate (min distance [{}])"), MinDistance), MinDistance > 0.0);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_MinusXChainMirrorsPlusXChain,
    "CkHands.Kernel.Solve_MinusXChainMirrorsPlusXChain",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_MinusXChainMirrorsPlusXChain::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    // Only the tip touches this sphere, so the tip direction decides the result. The -X chain is the +X chain
    // mirrored across the YZ plane: offsets along -X, bends of the opposite sign, the sphere at the mirrored point.
    const auto Settings = FCk_Hands_DigitContactSettings{};
    const auto Offset = 3.4 * FMath::Sqrt(0.5);

    const auto PlusXSphere = Make_Sphere(FVector{3.0 * kSegmentLength + Offset, -Offset, 0.0}, 0.3f);
    const auto PlusXCurl = ck::hands::Solve_DigitCurl(PlusXSphere, FTransform::Identity,
        Make_TipOnlyChain(kSegmentLength, 0.0), Make_TipOnlyChain(kSegmentLength, -1.0), Settings);

    const auto MinusXSphere = Make_Sphere(FVector{-3.0 * kSegmentLength - Offset, -Offset, 0.0}, 0.3f);
    const auto MinusXCurl = ck::hands::Solve_DigitCurl(MinusXSphere, FTransform::Identity,
        Make_TipOnlyChain(-kSegmentLength, 0.0), Make_TipOnlyChain(-kSegmentLength, 1.0), Settings);

    TestTrue(*ck::Format_UE(TEXT("+X chain: the tip stops partway (got [{}])"), PlusXCurl), PlusXCurl > 0.0f && PlusXCurl < 1.0f);
    TestTrue(*ck::Format_UE(TEXT("-X chain: the tip stops partway (got [{}])"), MinusXCurl), MinusXCurl > 0.0f && MinusXCurl < 1.0f);
    TestEqual(TEXT("the mirrored chain stops at the same curl"), MinusXCurl, PlusXCurl, 1.0e-4f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_NonIdentityParent,
    "CkHands.Kernel.Solve_NonIdentityParent",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_NonIdentityParent::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Rest = Make_StraightChain();
    const auto Pose = Make_CurledChain();
    const auto Settings = FCk_Hands_DigitContactSettings{};
    const auto Parent = FTransform{FRotator{20.0, 35.0, -10.0}, FVector{100.0, -50.0, 30.0}};

    const auto InHandSpace = Make_Sphere(FVector{9.0, -5.0, 0.0}, 2.0f);
    const auto InParentSpace = Make_Sphere(Parent.TransformPosition(FVector{9.0, -5.0, 0.0}), 2.0f);

    const auto IdentityCurl = ck::hands::Solve_DigitCurl(InHandSpace, FTransform::Identity, Rest, Pose, Settings);
    const auto ParentCurl = ck::hands::Solve_DigitCurl(InParentSpace, Parent, Rest, Pose, Settings);

    TestTrue(*ck::Format_UE(TEXT("the curl stops partway (got [{}])"), ParentCurl), ParentCurl > 0.0f && ParentCurl < 1.0f);
    TestEqual(TEXT("moving the hand and the shape together does not change the curl"), ParentCurl, IdentityCurl, 1.0e-3f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_RotatedShape,
    "CkHands.Kernel.Solve_RotatedShape",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_RotatedShape::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Rest = Make_StraightChain();
    const auto Pose = Make_CurledChain();
    const auto Settings = FCk_Hands_DigitContactSettings{};
    const auto Center = FVector{9.0, -5.0, 4.0};

    // Upright, the capsule reaches down through the digit's plane (Z = 0) where the curl passes.
    const auto Upright = Make_Capsule(FTransform{Center}, 6.0f, 0.5f);
    const auto UprightCurl = ck::hands::Solve_DigitCurl(Upright, FTransform::Identity, Rest, Pose, Settings);
    TestTrue(*ck::Format_UE(TEXT("upright: the curl stops partway (got [{}])"), UprightCurl), UprightCurl > 0.0f && UprightCurl < 1.0f);

    // Laid flat along Y it stays 4 cm above that plane.
    const auto LaidFlat = Make_Capsule(FTransform{FQuat{FVector::ForwardVector, FMath::DegreesToRadians(90.0)}, Center}, 6.0f, 0.5f);
    TestEqual(TEXT("laid flat: the full pose"), ck::hands::Solve_DigitCurl(LaidFlat, FTransform::Identity, Rest, Pose, Settings), 1.0f);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_RejectsInvalidShape,
    "CkHands.Kernel.Solve_RejectsInvalidShape",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_RejectsInvalidShape::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    Expect_RejectedWithFullCurl(*this, TEXT("negative sphere radius"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Make_Sphere(FVector{9.0, -5.0, 0.0}, -2.0f), FTransform::Identity,
            Make_StraightChain(), Make_CurledChain(), FCk_Hands_DigitContactSettings{});
    });

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_RejectsMismatchedSegmentCounts,
    "CkHands.Kernel.Solve_RejectsMismatchedSegmentCounts",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_RejectsMismatchedSegmentCounts::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    auto Pose = Make_CurledChain();
    Pose.Pop();

    Expect_RejectedWithFullCurl(*this, TEXT("3 rest segments, 2 pose segments"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Make_Sphere(FVector{9.0, -5.0, 0.0}, 2.0f), FTransform::Identity,
            Make_StraightChain(), Pose, FCk_Hands_DigitContactSettings{});
    });

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_RejectsSingleSegment,
    "CkHands.Kernel.Solve_RejectsSingleSegment",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_RejectsSingleSegment::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    Expect_RejectedWithFullCurl(*this, TEXT("a single segment"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Make_Sphere(FVector{9.0, -5.0, 0.0}, 2.0f), FTransform::Identity,
            TArray<FTransform>{Make_StraightChain()[0]}, TArray<FTransform>{Make_CurledChain()[0]}, FCk_Hands_DigitContactSettings{});
    });

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_RejectsInvalidSettings,
    "CkHands.Kernel.Solve_RejectsInvalidSettings",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_RejectsInvalidSettings::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Shape = Make_Sphere(FVector{9.0, -5.0, 0.0}, 2.0f);
    const auto Rest = Make_StraightChain();
    const auto Pose = Make_CurledChain();

    Expect_RejectedWithFullCurl(*this, TEXT("NaN radius"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Shape, FTransform::Identity, Rest, Pose,
            FCk_Hands_DigitContactSettings{}.Set_Radius(std::numeric_limits<float>::quiet_NaN()));
    });

    Expect_RejectedWithFullCurl(*this, TEXT("zero radius"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Shape, FTransform::Identity, Rest, Pose, FCk_Hands_DigitContactSettings{}.Set_Radius(0.0f));
    });

    Expect_RejectedWithFullCurl(*this, TEXT("fewer than 2 search steps"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Shape, FTransform::Identity, Rest, Pose, FCk_Hands_DigitContactSettings{}.Set_MaxSearchSteps(1));
    });

    Expect_RejectedWithFullCurl(*this, TEXT("infinite tip length ratio"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Shape, FTransform::Identity, Rest, Pose,
            FCk_Hands_DigitContactSettings{}.Set_TipLengthRatio(std::numeric_limits<float>::infinity()));
    });

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_Solve_RejectsNonFiniteTransforms,
    "CkHands.Kernel.Solve_RejectsNonFiniteTransforms",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_Solve_RejectsNonFiniteTransforms::RunTest(const FString&)
{
    using namespace ck_hands_kernel_spec;

    const auto Shape = Make_Sphere(FVector{9.0, -5.0, 0.0}, 2.0f);
    const auto NaN = std::numeric_limits<double>::quiet_NaN();

    Expect_RejectedWithFullCurl(*this, TEXT("NaN parent"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Shape, FTransform{FVector{NaN, 0.0, 0.0}}, Make_StraightChain(), Make_CurledChain(),
            FCk_Hands_DigitContactSettings{});
    });

    auto Pose = Make_CurledChain();
    Pose[1].SetTranslation(FVector{NaN, 0.0, 0.0});
    Expect_RejectedWithFullCurl(*this, TEXT("NaN pose translation"), [&]()
    {
        return ck::hands::Solve_DigitCurl(Shape, FTransform::Identity, Make_StraightChain(), Pose, FCk_Hands_DigitContactSettings{});
    });

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Kernel_GlovePlacement_LandsTargetBoneOnTarget,
    "CkHands.Kernel.GlovePlacement_LandsTargetBoneOnTarget",
    kCkUnitTestFlags)

bool FCkTest_Hands_Kernel_GlovePlacement_LandsTargetBoneOnTarget::RunTest(const FString&)
{
    const auto PlacedBone = FTransform{FRotator{10.0, 20.0, 30.0}, FVector{5.0, 6.0, 7.0}, FVector{2.0}};
    const auto TargetBoneLocal = FTransform{FRotator{0.0, 45.0, 0.0}, FVector{10.0, 0.0, 3.0}};
    const auto TargetBone = TargetBoneLocal * PlacedBone;
    const auto Target = FTransform{FRotator{-30.0, 60.0, 15.0}, FVector{100.0, 200.0, 300.0}, FVector{3.0}};

    const auto Placed = ck::hands::Get_GlovePlacement(PlacedBone, TargetBone, Target);
    const auto LandedTargetBone = TargetBoneLocal * Placed;

    TestTrue(TEXT("the placed bone keeps its own scale"), Placed.GetScale3D().Equals(PlacedBone.GetScale3D(), 1.0e-6));
    TestTrue(*ck::Format_UE(TEXT("the target bone lands on Target's location (got [{}])"), LandedTargetBone.GetLocation()),
        LandedTargetBone.GetLocation().Equals(Target.GetLocation(), 1.0e-3));
    TestTrue(TEXT("the target bone takes Target's rotation"),
        LandedTargetBone.GetRotation().Equals(Target.GetRotation(), 1.0e-4));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

#endif
