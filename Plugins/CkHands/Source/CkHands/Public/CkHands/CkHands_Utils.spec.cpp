#include "CkHands/CkHands_Utils.h"

#include "CkHands/CkHands_Kernel.h"
#include "CkHands/CkHands_UnitTest_Common.h"

#include "CkCore/Ensure/CkEnsure_Utils.h"
#include "CkCore/Format/CkFormat.h"

#include "Misc/AutomationTest.h"

#include <limits>

#if WITH_DEV_AUTOMATION_TESTS

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_utils_spec
{
    auto
        Make_InvalidSphere()
        -> FCk_Hands_ContactShape
    {
        return FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Sphere, FTransform{FVector{1.0, 2.0, 3.0}}}.Set_Radius(-2.0f);
    }

    // Ck ensures can reach more than one log sink and an ignored site logs nothing, so the log lines are only
    // suppressed (Occurrences -1) and the ensure COUNT is the enforceable assertion.
    auto
        Expect_EnsuredOnce(
            FAutomationTestBase& InTest,
            const TCHAR* InWhat,
            TFunctionRef<void()> InCall)
        -> void
    {
        constexpr auto IgnoreAllOccurrences = -1;
        InTest.AddExpectedErrorPlain(TEXT("Hands Utils"), EAutomationExpectedErrorFlags::Contains, IgnoreAllOccurrences);

        const auto EnsureCountBefore = UCk_Utils_Ensure_UE::Get_EnsureCount();
        InCall();

        InTest.TestEqual(*ck::Format_UE(TEXT("{}: ensured exactly once"), InWhat),
            UCk_Utils_Ensure_UE::Get_EnsureCount(), EnsureCountBefore + 1);
    }
}

using ck::hands::tests::kCkUnitTestFlags;

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Utils_MakersBuildValidShapes,
    "CkHands.Utils.MakersBuildValidShapes",
    kCkUnitTestFlags)

bool FCkTest_Hands_Utils_MakersBuildValidShapes::RunTest(const FString&)
{
    const auto Transform = FTransform{FRotator{10.0, 20.0, 30.0}, FVector{1.0, 2.0, 3.0}};
    const auto EnsureCountBefore = UCk_Utils_Ensure_UE::Get_EnsureCount();

    const auto Box = UCk_Utils_Hands_ContactShape_UE::Make_Box(Transform, FVector{1.0, 2.0, 3.0});
    TestTrue(TEXT("box type"), Box.Get_Type() == ECk_Hands_ContactShapeType::Box);
    TestTrue(TEXT("box half extents"), Box.Get_HalfExtents().Equals(FVector{1.0, 2.0, 3.0}));
    TestTrue(TEXT("box transform"), Box.Get_Transform().Equals(Transform));

    const auto Sphere = UCk_Utils_Hands_ContactShape_UE::Make_Sphere(Transform, 2.0f);
    TestTrue(TEXT("sphere type"), Sphere.Get_Type() == ECk_Hands_ContactShapeType::Sphere);
    TestEqual(TEXT("sphere radius"), Sphere.Get_Radius(), 2.0f);

    const auto Capsule = UCk_Utils_Hands_ContactShape_UE::Make_Capsule(Transform, 5.0f, 1.0f);
    TestTrue(TEXT("capsule type"), Capsule.Get_Type() == ECk_Hands_ContactShapeType::Capsule);
    TestEqual(TEXT("capsule half height"), Capsule.Get_HalfHeight(), 5.0f);
    TestEqual(TEXT("capsule radius"), Capsule.Get_Radius(), 1.0f);

    TestEqual(TEXT("valid shapes do not ensure"), UCk_Utils_Ensure_UE::Get_EnsureCount(), EnsureCountBefore);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Utils_MakersRejectInvalidShapes,
    "CkHands.Utils.MakersRejectInvalidShapes",
    kCkUnitTestFlags)

bool FCkTest_Hands_Utils_MakersRejectInvalidShapes::RunTest(const FString&)
{
    using namespace ck_hands_utils_spec;

    const auto NaN = std::numeric_limits<float>::quiet_NaN();

    auto Box = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Box, FTransform::Identity};
    Expect_EnsuredOnce(*this, TEXT("box with a negative half extent"), [&]()
    {
        Box = UCk_Utils_Hands_ContactShape_UE::Make_Box(FTransform::Identity, FVector{1.0, -1.0, 1.0});
    });
    TestTrue(TEXT("the rejected box is a None shape"), Box.Get_Type() == ECk_Hands_ContactShapeType::None);

    auto Sphere = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Sphere, FTransform::Identity};
    Expect_EnsuredOnce(*this, TEXT("sphere with a NaN radius"), [&]()
    {
        Sphere = UCk_Utils_Hands_ContactShape_UE::Make_Sphere(FTransform::Identity, NaN);
    });
    TestTrue(TEXT("the rejected sphere is a None shape"), Sphere.Get_Type() == ECk_Hands_ContactShapeType::None);

    auto Capsule = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Capsule, FTransform::Identity};
    Expect_EnsuredOnce(*this, TEXT("capsule with a negative half height"), [&]()
    {
        Capsule = UCk_Utils_Hands_ContactShape_UE::Make_Capsule(FTransform::Identity, -1.0f, 1.0f);
    });
    TestTrue(TEXT("the rejected capsule is a None shape"), Capsule.Get_Type() == ECk_Hands_ContactShapeType::None);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Utils_SignedDistanceRejectsInvalidShape,
    "CkHands.Utils.SignedDistanceRejectsInvalidShape",
    kCkUnitTestFlags)

bool FCkTest_Hands_Utils_SignedDistanceRejectsInvalidShape::RunTest(const FString&)
{
    using namespace ck_hands_utils_spec;

    const auto Valid = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Sphere, FTransform::Identity}.Set_Radius(2.0f);
    TestEqual(TEXT("a valid shape passes straight to the kernel"),
        UCk_Utils_Hands_ContactShape_UE::Get_SignedDistance(Valid, FVector{5.0, 0.0, 0.0}),
        ck::hands::Get_SignedDistance(Valid, FVector{5.0, 0.0, 0.0}));

    auto Distance = 0.0;
    Expect_EnsuredOnce(*this, TEXT("negative sphere radius"), [&]()
    {
        Distance = UCk_Utils_Hands_ContactShape_UE::Get_SignedDistance(Make_InvalidSphere(), FVector::ZeroVector);
    });
    TestEqual(TEXT("recovers as infinitely far, like a None shape"), Distance, TNumericLimits<double>::Max());

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Utils_InSpaceRejectsInvalidShape,
    "CkHands.Utils.InSpaceRejectsInvalidShape",
    kCkUnitTestFlags)

bool FCkTest_Hands_Utils_InSpaceRejectsInvalidShape::RunTest(const FString&)
{
    using namespace ck_hands_utils_spec;

    const auto Invalid = Make_InvalidSphere();
    const auto Space = FTransform{FRotator{0.0, 90.0, 0.0}, FVector{100.0, 0.0, 0.0}};

    auto InSpace = FCk_Hands_ContactShape{};
    Expect_EnsuredOnce(*this, TEXT("negative sphere radius"), [&]()
    {
        InSpace = UCk_Utils_Hands_ContactShape_UE::Get_InSpace(Invalid, Space);
    });

    TestTrue(TEXT("recovers with the input shape unchanged: type"), InSpace.Get_Type() == Invalid.Get_Type());
    TestEqual(TEXT("recovers with the input shape unchanged: radius"), InSpace.Get_Radius(), Invalid.Get_Radius());
    TestTrue(TEXT("recovers with the input shape unchanged: transform"), InSpace.Get_Transform().Equals(Invalid.Get_Transform(), 0.0));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Utils_AxisAndBoundsMakersMatchTheKernel,
    "CkHands.Utils.AxisAndBoundsMakersMatchTheKernel",
    kCkUnitTestFlags)

bool FCkTest_Hands_Utils_AxisAndBoundsMakersMatchTheKernel::RunTest(const FString&)
{
    const auto Transform = FTransform{FRotator{10.0, 20.0, 30.0}, FVector{1.0, 2.0, 3.0}};
    const auto Bounds = FBox{FVector{-2.0, -10.0, -4.0}, FVector{2.0, 10.0, 4.0}};
    const auto Probe = FVector{12.0, -7.0, 5.0};
    const auto EnsureCountBefore = UCk_Utils_Ensure_UE::Get_EnsureCount();

    const auto Capsule = UCk_Utils_Hands_ContactShape_UE::Make_CapsuleAlongAxis(Transform, ECk_Vector_Axis::X, 6.0f, 3.0f);
    TestTrue(TEXT("capsule along X: type"), Capsule.Get_Type() == ECk_Hands_ContactShapeType::Capsule);
    TestEqual(TEXT("capsule along X: the kernel's shape"),
        ck::hands::Get_SignedDistance(Capsule, Probe),
        ck::hands::Get_SignedDistance(ck::hands::Make_CapsuleAlongAxis(Transform, ECk_Vector_Axis::X, 6.0f, 3.0f), Probe));

    for (const auto Type : {ECk_Hands_ContactShapeType::Box, ECk_Hands_ContactShapeType::Sphere, ECk_Hands_ContactShapeType::Capsule})
    {
        const auto Shape = UCk_Utils_Hands_ContactShape_UE::Make_FromBounds(Transform, Bounds, Type);
        TestTrue(*ck::Format_UE(TEXT("from bounds [{}]: type"), Type), Shape.Get_Type() == Type);
        TestEqual(*ck::Format_UE(TEXT("from bounds [{}]: the kernel's shape"), Type),
            ck::hands::Get_SignedDistance(Shape, Probe),
            ck::hands::Get_SignedDistance(ck::hands::Make_ShapeFromBounds(Transform, Bounds, Type), Probe));
    }

    TestTrue(TEXT("a None type is a None shape"),
        UCk_Utils_Hands_ContactShape_UE::Make_FromBounds(Transform, Bounds, ECk_Hands_ContactShapeType::None).Get_Type()
            == ECk_Hands_ContactShapeType::None);

    TestEqual(TEXT("valid input does not ensure"), UCk_Utils_Ensure_UE::Get_EnsureCount(), EnsureCountBefore);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkTest_Hands_Utils_AxisAndBoundsMakersRejectInvalidInput,
    "CkHands.Utils.AxisAndBoundsMakersRejectInvalidInput",
    kCkUnitTestFlags)

bool FCkTest_Hands_Utils_AxisAndBoundsMakersRejectInvalidInput::RunTest(const FString&)
{
    using namespace ck_hands_utils_spec;

    auto TwoAxes = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Capsule, FTransform::Identity};
    Expect_EnsuredOnce(*this, TEXT("capsule along two axes"), [&]()
    {
        TwoAxes = UCk_Utils_Hands_ContactShape_UE::Make_CapsuleAlongAxis(
            FTransform::Identity, ECk_Vector_Axis::X | ECk_Vector_Axis::Z, 5.0f, 1.0f);
    });
    TestTrue(TEXT("the rejected two-axis capsule is a None shape"), TwoAxes.Get_Type() == ECk_Hands_ContactShapeType::None);

    auto NegativeRadius = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Capsule, FTransform::Identity};
    Expect_EnsuredOnce(*this, TEXT("capsule along X with a negative radius"), [&]()
    {
        NegativeRadius = UCk_Utils_Hands_ContactShape_UE::Make_CapsuleAlongAxis(FTransform::Identity, ECk_Vector_Axis::X, 5.0f, -1.0f);
    });
    TestTrue(TEXT("the rejected negative-radius capsule is a None shape"), NegativeRadius.Get_Type() == ECk_Hands_ContactShapeType::None);

    auto FromInvalidBox = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Box, FTransform::Identity};
    Expect_EnsuredOnce(*this, TEXT("shape from an invalid box"), [&]()
    {
        FromInvalidBox = UCk_Utils_Hands_ContactShape_UE::Make_FromBounds(
            FTransform::Identity, FBox{ForceInit}, ECk_Hands_ContactShapeType::Box);
    });
    TestTrue(TEXT("the shape from an invalid box is a None shape"), FromInvalidBox.Get_Type() == ECk_Hands_ContactShapeType::None);

    auto FromInsideOutBox = FCk_Hands_ContactShape{ECk_Hands_ContactShapeType::Box, FTransform::Identity};
    Expect_EnsuredOnce(*this, TEXT("shape from an inside-out box"), [&]()
    {
        FromInsideOutBox = UCk_Utils_Hands_ContactShape_UE::Make_FromBounds(
            FTransform::Identity, FBox{FVector{1.0}, FVector{-1.0}}, ECk_Hands_ContactShapeType::Box);
    });
    TestTrue(TEXT("the shape from an inside-out box is a None shape"), FromInsideOutBox.Get_Type() == ECk_Hands_ContactShapeType::None);

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

#endif
