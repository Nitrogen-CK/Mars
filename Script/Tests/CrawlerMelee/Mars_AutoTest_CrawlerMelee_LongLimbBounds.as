// Independent geometry checks for the game adapter; these do not stand in for live receipt/Jolt integration.
class UMars_AutoTest_CrawlerMelee_LongLimbBounds : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("full segment bound, moving targets, blocking and malformed geometry", n"Step_Check");
        Run_Steps(InHandle);
    }

    private FCk_ProceduralArticulation_LimbPose Make_Pose(FVector InCenter, FRotator InRotation,
        FVector InScale = FVector::OneVector)
    {
        auto Segments = TArray<FTransform>();
        const auto Segment = FTransform(InRotation, InCenter, InScale);
        Segments.Add(Segment);
        const auto Endpoint = FTransform(InCenter + Segment.GetRotation().GetForwardVector() * 50.0);
        return FCk_ProceduralArticulation_LimbPose(n"Arm", Endpoint, Endpoint, Segments, 0.0f,
            ECk_ProceduralRig_ChainState::Clear, ECk_ProceduralArticulation_ContactEvidence::None);
    }

    UFUNCTION()
    private void Step_Check(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Lengths = TArray<float32>();
        Lengths.Add(100.0f);
        auto Radii = TArray<float32>();
        Radii.Add(2.0f);
        auto Tuning = FMars_Crawler_LimbSweepTuning();
        auto ReceiptSpec = FMars_Crawler_LongLimbSpec();
        ReceiptSpec.LimbId = n"Arm";
        ReceiptSpec.SegmentLengths = Lengths;
        ReceiptSpec.SegmentRadii = Radii;
        ReceiptSpec.Sweep = Tuning;
        Assert_True(utils_crawler_long_limb_receipt::Validate(ReceiptSpec).IsValid(),
            "An explicit limb, frozen geometry and bounded target history admit receipt reconstruction");
        ReceiptSpec.MaxRetainedObservations = 1;
        Assert_True(utils_crawler_long_limb_receipt::Validate(ReceiptSpec).IsValid() == false,
            "A single target observation cannot bracket an accepted interval");
        ReceiptSpec.MaxRetainedObservations = 64;
        ReceiptSpec.MaxSpheresPerReceipt = 8193;
        Assert_True(utils_crawler_long_limb_receipt::Validate(ReceiptSpec).IsValid() == false,
            "Receipt geometry capacity has an explicit finite ceiling");
        auto Spheres = TArray<FMars_Crawler_LimbSweepSphere>();
        const auto From = Make_Pose(FVector(0.0, -20.0, 0.0), FRotator::ZeroRotator);
        const auto To = Make_Pose(FVector(0.0, 20.0, 0.0), FRotator::ZeroRotator);
        const auto Valid = utils_crawler_limb_sweep::Make_Interval(From, To, Lengths, Radii, Tuning, Spheres);
        Assert_True(Valid.IsValid() && Spheres.Num() == 26,
            "100cm link with 2cm radial bound requires 25 intervals and both endpoints");

        auto MidpointHit = false;
        for (const auto& Sphere : Spheres)
        {
            const auto Hit = utils_crawler_limb_sweep::Intersect_MovingSphere(Sphere,
                FVector::ZeroVector, FVector::ZeroVector, 1.0);
            Assert_True(Hit.Valid && Sphere.Radius <= 4.000001, "Every declared query respects its radial bound");
            MidpointHit = MidpointHit || Hit.Hit;
        }
        Assert_True(MidpointHit, "A target crossing the middle is covered");
        Assert_True(utils_crawler_limb_sweep::Intersect_MovingSphere(Spheres.Last(),
            FVector::ZeroVector, FVector::ZeroVector, 1.0).Hit == false, "Tip alone misses the same target");

        // Check the spatial proof over a rotating/deforming linear interval, not just query count.
        const auto Rotated = Make_Pose(FVector(20.0, 40.0, 0.0), FRotator(0.0, 120.0, 0.0));
        Assert_True(utils_crawler_limb_sweep::Make_Interval(From, Rotated, Lengths, Radii, Tuning, Spheres).IsValid(),
            "A large orientation change is represented by explicit piecewise-linear endpoint paths");
        auto MaxError = 0.0;
        for (auto Time = 0; Time <= 20; ++Time)
        {
            const auto Alpha = float64(Time) / 20.0;
            const auto Start = Math::Lerp(Spheres[0].From, Spheres[0].To, Alpha);
            const auto End = Math::Lerp(Spheres.Last().From, Spheres.Last().To, Alpha);
            for (auto Material = 0; Material <= 200; ++Material)
            {
                const auto Point = Math::Lerp(Start, End, float64(Material) / 200.0);
                auto Nearest = 1000000.0;
                for (const auto& Sphere : Spheres)
                { Nearest = Math::Min(Nearest, (Point - Math::Lerp(Sphere.From, Sphere.To, Alpha)).Size()); }
                MaxError = Math::Max(MaxError, Nearest);
            }
        }
        Assert_True(MaxError <= 2.000001, "The whole segment remains within the configured centerline coverage bound");

        auto Stationary = FMars_Crawler_LimbSweepSphere();
        Stationary.Radius = 2.0;
        const auto MovingTarget = utils_crawler_limb_sweep::Intersect_MovingSphere(Stationary,
            FVector(-10.0, 0.0, 0.0), FVector(10.0, 0.0, 0.0), 1.0);
        Assert_True(MovingTarget.Valid && MovingTarget.Hit && Math::Abs(MovingTarget.Fraction - 0.35) < 0.000001,
            "Relative sweep catches target movement even with a stationary limb");
        Assert_True(utils_crawler_limb_sweep::Get_CanCommit(MovingTarget, TOptional<float64>(0.3)) == false,
            "Earlier wall blocks target");
        Assert_True(utils_crawler_limb_sweep::Get_CanCommit(MovingTarget, TOptional<float64>(0.35)) == false,
            "Wall wins equal-time contact");
        Assert_True(utils_crawler_limb_sweep::Get_CanCommit(MovingTarget, TOptional<float64>(0.6)),
            "A later wall does not erase a prior target contact");

        const auto Scaled = Make_Pose(FVector(0.0, 20.0, 0.0), FRotator::ZeroRotator, FVector(4.0, 0.5, 2.0));
        Assert_True(utils_crawler_limb_sweep::Make_Interval(From, Scaled, Lengths, Radii, Tuning, Spheres).IsValid() &&
            (Spheres.Last().To - FVector(50.0, 20.0, 0.0)).Size() < 0.000001,
            "Visual scale does not change solver length or hit geometry");
        Tuning.MaxSamplesPerSegment = 4;
        Assert_True(utils_crawler_limb_sweep::Make_Interval(From, To, Lengths, Radii, Tuning, Spheres).IsValid() == false &&
            Spheres.Num() == 0, "Insufficient geometry budget rejects atomically with no queries");
        Tuning.MaxSamplesPerSegment = 65;
        Assert_True(utils_crawler_limb_sweep::Make_Interval(From, FCk_ProceduralArticulation_LimbPose(),
            Lengths, Radii, Tuning, Spheres).IsValid() == false && Spheres.Num() == 0,
            "Missing geometry never bridges an interval");
        Stationary.Radius = -1.0;
        Assert_True(utils_crawler_limb_sweep::Intersect_MovingSphere(Stationary,
            FVector::ZeroVector, FVector::ZeroVector, 1.0).Valid == false, "Malformed query is an invalid result");
    }
}
