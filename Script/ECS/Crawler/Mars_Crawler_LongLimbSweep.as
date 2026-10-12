// Game-owned collision adapter. The volume is the union of inflated swept spheres along each segment;
// it covers the piecewise-linear joint path with at most MaxExtraRadiusCm of extra radial reach.
// Visual scale never changes solver lengths. No requested pose, missing interval, or unbracketed target is valid input.
struct FMars_Crawler_LimbSweepTuning
{
    UPROPERTY()
    float32 MaxExtraRadiusCm = 2.0f;

    UPROPERTY()
    int32 MaxSamplesPerSegment = 65;
}

struct FMars_Crawler_LimbSweepSphere
{
    FVector From;
    FVector To;
    float64 Radius = 0.0;
}

struct FMars_Crawler_LimbSweepContact
{
    bool Valid = false;
    bool Hit = false;
    float64 Fraction = 1.0;
}

namespace utils_crawler_limb_sweep
{
    FMars_Validation Validate(const FMars_Crawler_LimbSweepTuning& InTuning,
        const TArray<float32>& InLengths, const TArray<float32>& InRadii)
    {
        if (utils_crawler::Get_IsPositiveFinite(InTuning.MaxExtraRadiusCm) == false ||
            InTuning.MaxSamplesPerSegment < 2 || InTuning.MaxSamplesPerSegment > 129)
        { return FMars_Validation("Limb sweep requires a positive radial error bound and 2..129 samples per segment"); }

        if (InLengths.Num() < 1 || InLengths.Num() > 8 || InRadii.Num() != InLengths.Num())
        { return FMars_Validation("Limb sweep requires 1..8 frozen lengths with one radius per segment"); }

        for (auto Index = 0; Index < InLengths.Num(); ++Index)
        {
            if (utils_crawler::Get_IsPositiveFinite(InLengths[Index]) == false ||
                utils_crawler::Get_IsPositiveFinite(InRadii[Index]) == false)
            { return FMars_Validation("Limb sweep lengths and radii must be positive and finite"); }

            if (float64(InLengths[Index]) / (2.0 * InTuning.MaxExtraRadiusCm) >
                float64(InTuning.MaxSamplesPerSegment - 1))
            { return FMars_Validation("Limb sweep sample capacity cannot satisfy the authored radial error bound"); }
        }
        return FMars_Validation();
    }

    // Validate the complete chain before producing any queries. Endpoints are copied accepted geometry.
    bool Get_IsChainValid(const FCk_ProceduralArticulation_LimbPose& InPose, const TArray<float32>& InLengths)
    {
        if (InPose.Get_Id().IsNone() || InPose.Get_Segments().Num() != InLengths.Num())
        { return false; }

        auto PreviousEnd = FVector::ZeroVector;
        for (auto Index = 0; Index < InLengths.Num(); ++Index)
        {
            const auto Segment = InPose.Get_Segments()[Index];
            if (Segment.ContainsNaN() || Segment.GetRotation().IsNormalized() == false ||
                utils_crawler::Get_IsFinite(Segment.GetLocation()) == false)
            { return false; }

            const auto Half = Segment.GetRotation().GetForwardVector() * (float64(InLengths[Index]) * 0.5);
            const auto Start = Segment.GetLocation() - Half;
            if (Index > 0 && (Start - PreviousEnd).Size() > 0.05)
            { return false; }
            PreviousEnd = Segment.GetLocation() + Half;
        }
        return utils_crawler::Get_IsFinite(InPose.Get_AcceptedEndpoint().GetLocation()) &&
            (PreviousEnd - InPose.Get_AcceptedEndpoint().GetLocation()).Size() <= 0.05;
    }

    FMars_Validation Make_Interval(const FCk_ProceduralArticulation_LimbPose& InFrom,
        const FCk_ProceduralArticulation_LimbPose& InTo, const TArray<float32>& InLengths,
        const TArray<float32>& InRadii, const FMars_Crawler_LimbSweepTuning& InTuning,
        TArray<FMars_Crawler_LimbSweepSphere>& OutSpheres)
    {
        OutSpheres.Reset();
        const auto Validation = Validate(InTuning, InLengths, InRadii);
        if (Validation.IsValid() == false)
        { return Validation; }

        if (InFrom.Get_Id() != InTo.Get_Id() || Get_IsChainValid(InFrom, InLengths) == false ||
            Get_IsChainValid(InTo, InLengths) == false)
        { return FMars_Validation("Limb sweep requires matching identities and complete contiguous accepted chains"); }

        for (auto Index = 0; Index < InLengths.Num(); ++Index)
        {
            const auto Length = float64(InLengths[Index]);
            const auto RequiredIntervals = Length / (2.0 * InTuning.MaxExtraRadiusCm);
            auto Intervals = Math::Max(1, int32(RequiredIntervals));
            if (float64(Intervals) < RequiredIntervals)
            { ++Intervals; }

            const auto Radius = float64(InRadii[Index]) + Length / (2.0 * float64(Intervals));
            const auto From = InFrom.Get_Segments()[Index];
            const auto To = InTo.Get_Segments()[Index];
            for (auto Sample = 0; Sample <= Intervals; ++Sample)
            {
                const auto Local = Length * (float64(Sample) / float64(Intervals) - 0.5);
                auto Sphere = FMars_Crawler_LimbSweepSphere();
                Sphere.From = From.GetLocation() + From.GetRotation().GetForwardVector() * Local;
                Sphere.To = To.GetLocation() + To.GetRotation().GetForwardVector() * Local;
                Sphere.Radius = Radius;
                OutSpheres.Add(Sphere);
            }
        }
        return FMars_Validation();
    }

    // Both center paths belong to the SAME two world observations. Playback time is not a substitute.
    FMars_Crawler_LimbSweepContact Intersect_MovingSphere(const FMars_Crawler_LimbSweepSphere& InSweep,
        FVector InTargetFrom, FVector InTargetTo, float64 InTargetRadius)
    {
        auto Result = FMars_Crawler_LimbSweepContact();
        if (utils_crawler::Get_IsFinite(InSweep.From) == false || utils_crawler::Get_IsFinite(InSweep.To) == false ||
            utils_crawler::Get_IsFinite(InTargetFrom) == false || utils_crawler::Get_IsFinite(InTargetTo) == false ||
            Math::IsFinite(InSweep.Radius) == false || InSweep.Radius <= 0.0 ||
            Math::IsFinite(InTargetRadius) == false || InTargetRadius <= 0.0)
        { return Result; }

        const auto Start = InSweep.From - InTargetFrom;
        const auto Velocity = (InSweep.To - InSweep.From) - (InTargetTo - InTargetFrom);
        const auto Radius = InSweep.Radius + InTargetRadius;
        const auto A = Velocity.DotProduct(Velocity);
        const auto B = Start.DotProduct(Velocity);
        const auto C = Start.DotProduct(Start) - Radius * Radius;
        const auto Discriminant = B * B - A * C;
        if (Math::IsFinite(A) == false || Math::IsFinite(B) == false || Math::IsFinite(C) == false ||
            Math::IsFinite(Discriminant) == false)
        { return Result; }

        Result.Valid = true;
        if (C <= 0.0)
        {
            Result.Hit = true;
            Result.Fraction = 0.0;
            return Result;
        }
        if (A <= 1.0e-12 || B >= 0.0 || Discriminant < 0.0)
        { return Result; }

        // Equivalent to (-B - sqrt(D)) / A without cancellation for a distant approaching sphere.
        const auto Fraction = C / (-B + Math::Sqrt(Discriminant));
        Result.Hit = Fraction >= 0.0 && Fraction <= 1.0;
        Result.Fraction = Result.Hit ? Fraction : 1.0;
        return Result;
    }

    // A world obstruction wins equal-time contacts. Fractions must use the same inflated sphere proxy.
    bool Get_CanCommit(const FMars_Crawler_LimbSweepContact& InTarget, TOptional<float64> InWallFraction)
    {
        if (InTarget.Valid == false || InTarget.Hit == false || Math::IsFinite(InTarget.Fraction) == false ||
            InTarget.Fraction < 0.0 || InTarget.Fraction > 1.0)
        { return false; }
        if (InWallFraction.IsSet() == false)
        { return true; }
        const auto Wall = InWallFraction.GetValue();
        return Math::IsFinite(Wall) && Wall >= 0.0 && Wall <= 1.0 && InTarget.Fraction + 1.0e-6 < Wall;
    }
}
