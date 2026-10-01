#include "CkHands/CkHands_Kernel.h"

#include "CkCore/Ensure/CkEnsure.h"

#include <Algo/AnyOf.h>
#include <CapsuleTypes.h>
#include <FrameTypes.h>
#include <OrientedBoxTypes.h>
#include <SegmentTypes.h>
#include <SphereTypes.h>

// --------------------------------------------------------------------------------------------------------------------

namespace ck_hands_kernel
{
    constexpr auto kRefinementIterations = 4;

    using JointsType = TArray<FTransform, TInlineAllocator<8>>;
    using PointsType = TArray<FVector, TInlineAllocator<64>>;
    using DistancesType = TArray<double, TInlineAllocator<64>>;

    // Measured once on the rest pose: rigid rotations keep every segment's length, so the sample layout is shared by
    // every curl and sample N of one curl is the same point of the digit as sample N of another.
    struct FDigitSampling
    {
        TArray<double, TInlineAllocator<8>> _SegmentLengths;
        TArray<int32, TInlineAllocator<8>> _SegmentSampleCounts;
        double _TipLength = 0.0;
        int32 _TipSampleCount = 0;
    };

    auto
        DoGet_IsFiniteAndNonNegative(
            double InValue)
        -> bool
    {
        return FMath::IsFinite(InValue) && InValue >= 0.0;
    }

    auto
        DoGet_IsChainFinite(
            const FTransform& InParent,
            TConstArrayView<FTransform> InRest,
            TConstArrayView<FTransform> InPose)
        -> bool
    {
        const auto IsNonFinite = [](const FTransform& InTransform) { return InTransform.ContainsNaN(); };
        return NOT InParent.ContainsNaN()
            && NOT Algo::AnyOf(InRest, IsNonFinite)
            && NOT Algo::AnyOf(InPose, IsNonFinite);
    }

    auto
        DoGet_RigidTransform(
            const FTransform& InTransform)
        -> FTransform
    {
        return FTransform{InTransform.GetRotation(), InTransform.GetTranslation()};
    }

    auto
        DoGet_TipOffset(
            TConstArrayView<FTransform> InPose,
            float InTipLengthRatio)
        -> FVector
    {
        return InPose.Last().GetTranslation() * InTipLengthRatio;
    }

    auto
        DoCompute_Joints(
            const FTransform& InParent,
            TConstArrayView<FTransform> InRest,
            TConstArrayView<FTransform> InPose,
            float InCurl,
            JointsType& OutJoints)
        -> void
    {
        OutJoints.Reset();

        auto Parent = InParent;
        for (auto Segment = 0; Segment < InPose.Num(); ++Segment)
        {
            const auto& Pose = InPose[Segment];
            const auto Rotation = FQuat::Slerp(InRest[Segment].GetRotation(), Pose.GetRotation(), InCurl);
            Parent = FTransform{Rotation, Pose.GetTranslation(), Pose.GetScale3D()} * Parent;
            OutJoints.Add(Parent);
        }
    }

    auto
        DoGet_SampleCount(
            double InLength,
            float InSpacing)
        -> int32
    {
        return FMath::Max(1, FMath::CeilToInt32(InLength / InSpacing));
    }

    auto
        DoMake_Sampling(
            const JointsType& InRestJoints,
            const FVector& InTipOffset,
            float InSpacing)
        -> FDigitSampling
    {
        auto Sampling = FDigitSampling{};
        for (auto Joint = 1; Joint < InRestJoints.Num(); ++Joint)
        {
            const auto Length = FVector::Dist(InRestJoints[Joint - 1].GetLocation(), InRestJoints[Joint].GetLocation());
            Sampling._SegmentLengths.Add(Length);
            Sampling._SegmentSampleCounts.Add(DoGet_SampleCount(Length, InSpacing));
        }

        if (InTipOffset.IsNearlyZero())
        { return Sampling; }

        const auto& LastJoint = InRestJoints.Last();
        Sampling._TipLength = FVector::Dist(LastJoint.GetLocation(), LastJoint.TransformPosition(InTipOffset));
        Sampling._TipSampleCount = DoGet_SampleCount(Sampling._TipLength, InSpacing);
        return Sampling;
    }

    auto
        DoAppend_SegmentSamples(
            const FVector& InStart,
            const FVector& InEnd,
            int32 InSampleCount,
            PointsType& OutPoints)
        -> void
    {
        for (auto Sample = 1; Sample <= InSampleCount; ++Sample)
        { OutPoints.Add(FMath::Lerp(InStart, InEnd, static_cast<double>(Sample) / static_cast<double>(InSampleCount))); }
    }

    auto
        DoCompute_Points(
            const JointsType& InJoints,
            const FVector& InTipOffset,
            const FDigitSampling& InSampling,
            PointsType& OutPoints)
        -> void
    {
        OutPoints.Reset();

        for (auto Joint = 1; Joint < InJoints.Num(); ++Joint)
        {
            DoAppend_SegmentSamples(InJoints[Joint - 1].GetLocation(), InJoints[Joint].GetLocation(),
                InSampling._SegmentSampleCounts[Joint - 1], OutPoints);
        }

        if (InSampling._TipSampleCount == 0)
        { return; }

        const auto& LastJoint = InJoints.Last();
        DoAppend_SegmentSamples(LastJoint.GetLocation(), LastJoint.TransformPosition(InTipOffset),
            InSampling._TipSampleCount, OutPoints);
    }

    auto
        DoCompute_Distances(
            const FCk_Hands_ContactShape& InShape,
            const PointsType& InPoints,
            DistancesType& OutDistances)
        -> void
    {
        OutDistances.Reset();

        for (const auto& Point : InPoints)
        { OutDistances.Add(ck::hands::Get_SignedDistance(InShape, Point)); }
    }

    auto
        DoGet_IsNewlyTouching(
            const DistancesType& InRestDistances,
            const DistancesType& InDistances,
            float InRadius)
        -> bool
    {
        for (auto Index = 0; Index < InDistances.Num(); ++Index)
        {
            if (InRestDistances[Index] >= InRadius && InDistances[Index] < InRadius)
            { return true; }
        }
        return false;
    }

    auto
        DoGet_SearchSteps(
            TConstArrayView<FTransform> InRest,
            TConstArrayView<FTransform> InPose,
            const FDigitSampling& InSampling,
            const FCk_Hands_DigitContactSettings& InSettings)
        -> int32
    {
        auto Reach = InSampling._TipLength;
        auto TravelPerCurl = 0.0;
        for (auto Joint = InPose.Num() - 1; Joint >= 0; --Joint)
        {
            TravelPerCurl += InRest[Joint].GetRotation().AngularDistance(InPose[Joint].GetRotation()) * Reach;

            if (Joint > 0)
            { Reach += InSampling._SegmentLengths[Joint - 1]; }
        }

        const auto MaxSteps = InSettings.Get_MaxSearchSteps();
        const auto NeededSteps = TravelPerCurl / InSettings.Get_Radius();
        if (NeededSteps >= MaxSteps)
        { return MaxSteps; }

        return FMath::Max(2, FMath::CeilToInt32(NeededSteps));
    }
}

// --------------------------------------------------------------------------------------------------------------------

auto
    ck::hands::Get_IsShapeValid(
        const FCk_Hands_ContactShape& InShape)
    -> bool
{
    const auto Type = InShape.Get_Type();
    if (Type == ECk_Hands_ContactShapeType::None)
    { return true; }

    const auto& Transform = InShape.Get_Transform();
    if (Transform.ContainsNaN() || NOT Transform.IsRotationNormalized())
    { return false; }

    switch (Type)
    {
        case ECk_Hands_ContactShapeType::Box:
        {
            const auto& HalfExtents = InShape.Get_HalfExtents();
            return ck_hands_kernel::DoGet_IsFiniteAndNonNegative(HalfExtents.X)
                && ck_hands_kernel::DoGet_IsFiniteAndNonNegative(HalfExtents.Y)
                && ck_hands_kernel::DoGet_IsFiniteAndNonNegative(HalfExtents.Z);
        }
        case ECk_Hands_ContactShapeType::Sphere:
        {
            return ck_hands_kernel::DoGet_IsFiniteAndNonNegative(InShape.Get_Radius());
        }
        case ECk_Hands_ContactShapeType::Capsule:
        {
            return ck_hands_kernel::DoGet_IsFiniteAndNonNegative(InShape.Get_Radius())
                && ck_hands_kernel::DoGet_IsFiniteAndNonNegative(InShape.Get_HalfHeight());
        }
        default:
        {
            CK_INVALID_ENUM(Type);
            return false;
        }
    }
}

// --------------------------------------------------------------------------------------------------------------------

auto
    ck::hands::Get_IsSettingsValid(
        const FCk_Hands_DigitContactSettings& InSettings)
    -> bool
{
    return FMath::IsFinite(InSettings.Get_Radius()) && InSettings.Get_Radius() > 0.0f
        && InSettings.Get_MaxSearchSteps() >= 2
        && ck_hands_kernel::DoGet_IsFiniteAndNonNegative(InSettings.Get_TipLengthRatio());
}

// --------------------------------------------------------------------------------------------------------------------

auto
    ck::hands::Get_SignedDistance(
        const FCk_Hands_ContactShape& InShape,
        const FVector& InPoint)
    -> double
{
    const auto Type = InShape.Get_Type();
    if (Type == ECk_Hands_ContactShapeType::None)
    { return TNumericLimits<double>::Max(); }

    const auto Frame = UE::Geometry::TFrame3<double>{InShape.Get_Transform()};

    switch (Type)
    {
        case ECk_Hands_ContactShapeType::Box:
        {
            return UE::Geometry::TOrientedBox3<double>{Frame, InShape.Get_HalfExtents()}.SignedDistance(InPoint);
        }
        case ECk_Hands_ContactShapeType::Sphere:
        {
            return UE::Geometry::TSphere3<double>{Frame.Origin, InShape.Get_Radius()}.SignedDistance(InPoint);
        }
        case ECk_Hands_ContactShapeType::Capsule:
        {
            constexpr auto LocalZ = 2;
            const auto Core = UE::Geometry::TSegment3<double>{Frame.Origin, Frame.GetAxis(LocalZ), InShape.Get_HalfHeight()};
            return UE::Geometry::TCapsule3<double>{Core, InShape.Get_Radius()}.SignedDistance(InPoint);
        }
        default:
        {
            CK_INVALID_ENUM(Type);
            return TNumericLimits<double>::Max();
        }
    }
}

// --------------------------------------------------------------------------------------------------------------------

auto
    ck::hands::Get_ShapeInSpace(
        const FCk_Hands_ContactShape& InShape,
        const FTransform& InSpace)
    -> FCk_Hands_ContactShape
{
    auto Shape = InShape;
    Shape.Set_Transform(ck_hands_kernel::DoGet_RigidTransform(InShape.Get_Transform())
        .GetRelativeTransform(ck_hands_kernel::DoGet_RigidTransform(InSpace)));
    return Shape;
}

// --------------------------------------------------------------------------------------------------------------------

auto
    ck::hands::Solve_DigitCurl(
        const FCk_Hands_ContactShape& InShape,
        const FTransform& InParent,
        TConstArrayView<FTransform> InRest,
        TConstArrayView<FTransform> InPose,
        const FCk_Hands_DigitContactSettings& InSettings)
    -> float
{
    if (InShape.Get_Type() == ECk_Hands_ContactShapeType::None)
    { return 1.0f; }

    const auto IsShapeValid = Get_IsShapeValid(InShape);
    CK_ENSURE_IF_NOT(IsShapeValid, TEXT("Solve_DigitCurl rejected an invalid [{}] contact shape"), InShape.Get_Type())
    { return 1.0f; }

    const auto HasMatchingCounts = InRest.Num() == InPose.Num();
    CK_ENSURE_IF_NOT(HasMatchingCounts, TEXT("Solve_DigitCurl rejected a digit with [{}] rest and [{}] pose segments"),
        InRest.Num(), InPose.Num())
    { return 1.0f; }

    const auto IsChain = InPose.Num() >= 2;
    CK_ENSURE_IF_NOT(IsChain, TEXT("Solve_DigitCurl rejected a digit of [{}] segments, it needs at least 2"), InPose.Num())
    { return 1.0f; }

    const auto IsSettingsValid = Get_IsSettingsValid(InSettings);
    CK_ENSURE_IF_NOT(IsSettingsValid,
        TEXT("Solve_DigitCurl rejected invalid settings: Radius [{}], MaxSearchSteps [{}], TipLengthRatio [{}]"),
        InSettings.Get_Radius(), InSettings.Get_MaxSearchSteps(), InSettings.Get_TipLengthRatio())
    { return 1.0f; }

    const auto IsChainFinite = ck_hands_kernel::DoGet_IsChainFinite(InParent, InRest, InPose);
    CK_ENSURE_IF_NOT(IsChainFinite, TEXT("Solve_DigitCurl rejected a digit with non-finite parent, rest or pose transforms"))
    { return 1.0f; }

    constexpr auto RestCurl = 0.0f;
    auto Joints = ck_hands_kernel::JointsType{};
    ck_hands_kernel::DoCompute_Joints(InParent, InRest, InPose, RestCurl, Joints);

    const auto TipOffset = ck_hands_kernel::DoGet_TipOffset(InPose, InSettings.Get_TipLengthRatio());
    const auto Sampling = ck_hands_kernel::DoMake_Sampling(Joints, TipOffset, InSettings.Get_Radius());

    auto Points = ck_hands_kernel::PointsType{};
    auto RestDistances = ck_hands_kernel::DistancesType{};
    ck_hands_kernel::DoCompute_Points(Joints, TipOffset, Sampling, Points);
    ck_hands_kernel::DoCompute_Distances(InShape, Points, RestDistances);

    auto Distances = ck_hands_kernel::DistancesType{};
    const auto IsNewlyTouchingAt = [&](float InCurl) -> bool
    {
        ck_hands_kernel::DoCompute_Joints(InParent, InRest, InPose, InCurl, Joints);
        ck_hands_kernel::DoCompute_Points(Joints, TipOffset, Sampling, Points);
        ck_hands_kernel::DoCompute_Distances(InShape, Points, Distances);
        return ck_hands_kernel::DoGet_IsNewlyTouching(RestDistances, Distances, InSettings.Get_Radius());
    };

    const auto Steps = ck_hands_kernel::DoGet_SearchSteps(InRest, InPose, Sampling, InSettings);

    auto Clear = 0.0f;
    for (auto Step = 1; Step <= Steps; ++Step)
    {
        const auto Curl = static_cast<float>(Step) / static_cast<float>(Steps);
        if (NOT IsNewlyTouchingAt(Curl))
        {
            Clear = Curl;
            continue;
        }

        auto Touch = Curl;
        for (auto Iteration = 0; Iteration < ck_hands_kernel::kRefinementIterations; ++Iteration)
        {
            const auto Mid = (Clear + Touch) * 0.5f;
            if (IsNewlyTouchingAt(Mid))
            { Touch = Mid; }
            else
            { Clear = Mid; }
        }
        return Clear;
    }
    return 1.0f;
}

// --------------------------------------------------------------------------------------------------------------------

auto
    ck::hands::Get_GlovePlacement(
        const FTransform& InPlacedBone,
        const FTransform& InTargetBone,
        const FTransform& InTarget)
    -> FTransform
{
    const auto PlacedInTargetBone = ck_hands_kernel::DoGet_RigidTransform(InPlacedBone)
        .GetRelativeTransform(ck_hands_kernel::DoGet_RigidTransform(InTargetBone));

    auto Placed = PlacedInTargetBone * ck_hands_kernel::DoGet_RigidTransform(InTarget);
    Placed.SetScale3D(InPlacedBone.GetScale3D());
    return Placed;
}

// --------------------------------------------------------------------------------------------------------------------
