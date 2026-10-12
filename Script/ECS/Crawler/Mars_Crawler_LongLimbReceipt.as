// Game-owned interpretation of copied Action receipts. The attack chooses the target sphere, collision window,
// frozen topology and damage policy. Evaluated samples describe a declared path, not rendered intermediate frames.
struct FMars_Crawler_LongLimbSpec
{
    UPROPERTY()
    FName LimbId;

    UPROPERTY()
    TArray<float32> SegmentLengths;

    UPROPERTY()
    TArray<float32> SegmentRadii;

    UPROPERTY()
    FMars_Crawler_LimbSweepTuning Sweep;

    UPROPERTY()
    float32 TargetRadiusCm = 10.0f;

    UPROPERTY()
    int32 MaxRetainedObservations = 64;

    UPROPERTY()
    int32 MaxSpheresPerReceipt = 2048;
}

struct FMars_Crawler_LongLimbTargetObservation
{
    int64 SubjectPoseRevision = 0;
    FVector Center = FVector::ZeroVector;
}

struct FMars_Crawler_LongLimbSweepStep
{
    TArray<FMars_Crawler_LimbSweepSphere> Spheres;
    FVector TargetFrom = FVector::ZeroVector;
    FVector TargetTo = FVector::ZeroVector;
}

struct FMars_Crawler_LongLimbResolution
{
    bool Valid = false;
    bool SeedOnly = false;
    TArray<FMars_Crawler_LongLimbSweepStep> Steps;
    FString Failure;
}

// Keep this state with one game action and one explicit target. Receipt cursor/consume ownership lives in the caller.
struct FMars_Crawler_LongLimbReceiptState
{
    FMars_Crawler_LongLimbSpec Spec;
    FCk_ProceduralAction_Identity Identity;
    int64 TopologyRevision = 0;
    int64 LastSampleSequence = 0;
    int64 LastAcceptedSubjectRevision = 0;
    FCk_ProceduralArticulation_LimbPose LastAcceptedLimb;
    bool HasLastAcceptedLimb = false;
    bool Closed = false;
    TArray<FMars_Crawler_LongLimbTargetObservation> TargetHistory;
}

namespace utils_crawler_long_limb_receipt
{
    FMars_Validation Validate(const FMars_Crawler_LongLimbSpec& InSpec)
    {
        if (InSpec.LimbId.IsNone() || utils_crawler::Get_IsPositiveFinite(InSpec.TargetRadiusCm) == false ||
            InSpec.MaxRetainedObservations < 2 || InSpec.MaxRetainedObservations > 256 ||
            InSpec.MaxSpheresPerReceipt < 2 || InSpec.MaxSpheresPerReceipt > 8192)
        { return FMars_Validation("Long-limb attack requires a limb, positive target radius and bounded history/query capacity"); }
        return utils_crawler_limb_sweep::Validate(InSpec.Sweep, InSpec.SegmentLengths, InSpec.SegmentRadii);
    }

    bool Begin(FMars_Crawler_LongLimbReceiptState& OutState, const FMars_Crawler_LongLimbSpec& InSpec,
        FCk_ProceduralAction_Identity InIdentity, int64 InTopologyRevision)
    {
        if (Validate(InSpec).IsValid() == false || InIdentity.Get_Value() <= 0 || InTopologyRevision <= 0)
        { return false; }
        OutState = FMars_Crawler_LongLimbReceiptState();
        OutState.Spec = InSpec;
        OutState.Identity = InIdentity;
        OutState.TopologyRevision = InTopologyRevision;
        return true;
    }

    // Capture once at the observation boundary; do not replace a historical center with its later current position.
    bool ObserveTarget(FMars_Crawler_LongLimbReceiptState& InOutState, int64 InSubjectPoseRevision, FVector InCenter)
    {
        if (InOutState.Closed || InSubjectPoseRevision <= 0 || utils_crawler::Get_IsFinite(InCenter) == false)
        { return false; }
        if (InOutState.TargetHistory.Num() > 0 &&
            InSubjectPoseRevision <= InOutState.TargetHistory.Last().SubjectPoseRevision)
        {
            const auto& Last = InOutState.TargetHistory.Last();
            if (InSubjectPoseRevision == Last.SubjectPoseRevision &&
                (InCenter - Last.Center).Size() <= 0.05)
            { return true; }
            InOutState.Closed = true;
            return false;
        }
        auto Observation = FMars_Crawler_LongLimbTargetObservation();
        Observation.SubjectPoseRevision = InSubjectPoseRevision;
        Observation.Center = InCenter;
        InOutState.TargetHistory.Add(Observation);
        if (InOutState.TargetHistory.Num() > InOutState.Spec.MaxRetainedObservations)
        { InOutState.TargetHistory.RemoveAt(0); }
        return true;
    }

    bool TryFindTarget(const FMars_Crawler_LongLimbReceiptState& InState, int64 InRevision, FVector& OutCenter)
    {
        for (const auto& Observation : InState.TargetHistory)
        {
            if (Observation.SubjectPoseRevision == InRevision)
            {
                OutCenter = Observation.Center;
                return true;
            }
        }
        return false;
    }

    bool TryFindLimb(const FCk_ProceduralArticulation_Pose& InPose, FName InId,
        FCk_ProceduralArticulation_LimbPose& OutLimb)
    {
        for (const auto& Limb : InPose.Get_Limbs())
        {
            if (Limb.Get_Id() == InId)
            {
                OutLimb = Limb;
                return true;
            }
        }
        return false;
    }

    bool Get_MatchesLastAccepted(const FMars_Crawler_LongLimbReceiptState& InState,
        const FCk_ProceduralArticulation_LimbPose& InPrevious)
    {
        if (InState.HasLastAcceptedLimb == false ||
            InPrevious.Get_Id() != InState.LastAcceptedLimb.Get_Id() ||
            InPrevious.Get_Segments().Num() != InState.LastAcceptedLimb.Get_Segments().Num())
        { return false; }
        for (auto Index = 0; Index < InPrevious.Get_Segments().Num(); ++Index)
        {
            const auto& A = InPrevious.Get_Segments()[Index];
            const auto& B = InState.LastAcceptedLimb.Get_Segments()[Index];
            if ((A.GetLocation() - B.GetLocation()).Size() > 0.05 ||
                Math::RadiansToDegrees(A.GetRotation().AngularDistance(B.GetRotation())) > 0.05)
            { return false; }
        }
        return (InPrevious.Get_AcceptedEndpoint().GetLocation() -
            InState.LastAcceptedLimb.Get_AcceptedEndpoint().GetLocation()).Size() <= 0.05;
    }

    // Fail closed on any missing interval. A FirstSample or unknown admission bracket only seeds the next interval.
    FMars_Crawler_LongLimbResolution ResolveAccepted(FMars_Crawler_LongLimbReceiptState& InOutState,
        const FCk_ProceduralAction_Receipt& InReceipt, bool InEvaluateMotion = true)
    {
        auto Result = FMars_Crawler_LongLimbResolution();
        if (InOutState.Closed || InReceipt.Get_HasAcceptedPose() == false ||
            InReceipt.Get_Stamp().Get_Identity().Get_Value() != InOutState.Identity.Get_Value() ||
            InReceipt.Get_Stamp().Get_TopologyRevision() != InOutState.TopologyRevision ||
            InReceipt.Get_Stamp().Get_SubjectPoseRevision() <= 0 ||
            InReceipt.Get_Stamp().Get_SampleSequence() <= InOutState.LastSampleSequence)
        { Result.Failure = "Invalid accepted receipt identity, topology or order"; InOutState.Closed = true; return Result; }

        auto Current = FCk_ProceduralArticulation_LimbPose();
        if (TryFindLimb(InReceipt.Get_CurrentPose(), InOutState.Spec.LimbId, Current) == false ||
            utils_crawler_limb_sweep::Get_IsChainValid(Current, InOutState.Spec.SegmentLengths) == false)
        { Result.Failure = "Accepted receipt has no complete limb chain"; InOutState.Closed = true; return Result; }

        const auto Revision = InReceipt.Get_Stamp().Get_SubjectPoseRevision();
        InOutState.LastSampleSequence = InReceipt.Get_Stamp().Get_SampleSequence();
        if (InOutState.HasLastAcceptedLimb == false)
        {
            InOutState.LastAcceptedLimb = Current;
            InOutState.HasLastAcceptedLimb = true;
            InOutState.LastAcceptedSubjectRevision = Revision;
            Result.Valid = true;
            Result.SeedOnly = true;
            return Result;
        }

        auto Previous = FCk_ProceduralArticulation_LimbPose();
        if (InReceipt.Get_Interval().Get_Continuity() != ECk_ProceduralAction_Continuity::Continuous ||
            Revision <= InOutState.LastAcceptedSubjectRevision ||
            TryFindLimb(InReceipt.Get_PreviousPose(), InOutState.Spec.LimbId, Previous) == false ||
            Get_MatchesLastAccepted(InOutState, Previous) == false)
        { Result.Failure = "Accepted limb history is discontinuous"; InOutState.Closed = true; return Result; }

        auto TargetFrom = FVector::ZeroVector;
        auto TargetTo = FVector::ZeroVector;
        if (TryFindTarget(InOutState, InOutState.LastAcceptedSubjectRevision, TargetFrom) == false ||
            TryFindTarget(InOutState, Revision, TargetTo) == false)
        { Result.Failure = "Matching target world observation bracket is missing"; InOutState.Closed = true; return Result; }

        const auto FromSeconds = InReceipt.Get_Interval().Get_FromTime().Get_Seconds();
        const auto ToSeconds = InReceipt.Get_Interval().Get_ToTime().Get_Seconds();
        const auto Duration = ToSeconds - FromSeconds;
        if (Math::IsFinite(Duration) == false || Duration < 0.0)
        { Result.Failure = "Accepted interval clock is invalid"; InOutState.Closed = true; return Result; }

        // Entry blending publishes real geometry while the authored clock remains at zero.
        // Outside the consumer's hit window only the settled endpoint seeds the next interval;
        // evaluated entry poses cannot be mapped to target time using that frozen clip clock.
        if (InEvaluateMotion == false)
        {
            InOutState.LastAcceptedLimb = Current;
            InOutState.LastAcceptedSubjectRevision = Revision;
            Result.Valid = true;
            Result.SeedOnly = true;
            return Result;
        }
        if ((Duration == 0.0 && InReceipt.Get_IntermediateSamples().Num() > 0) ||
            InReceipt.Get_IntermediateSamples().Num() > 64)
        { Result.Failure = "Accepted sample times are unrepresentable"; InOutState.Closed = true; return Result; }

        auto LastLimb = Previous;
        auto LastFraction = 0.0;
        auto SphereCount = 0;
        for (auto Index = 0; Index <= InReceipt.Get_IntermediateSamples().Num(); ++Index)
        {
            auto NextLimb = Current;
            auto Fraction = 1.0;
            if (Index < InReceipt.Get_IntermediateSamples().Num())
            {
                const auto& Sample = InReceipt.Get_IntermediateSamples()[Index];
                const auto Seconds = Sample.Get_Time().Get_Seconds();
                if (Sample.Get_Evidence() != ECk_ProceduralAction_SampleEvidence::Evaluated ||
                    Duration <= 0.0 || Math::IsFinite(Seconds) == false ||
                    Seconds <= FromSeconds || Seconds >= ToSeconds ||
                    TryFindLimb(Sample.Get_Pose(), InOutState.Spec.LimbId, NextLimb) == false)
                { Result.Failure = "Malformed evaluated sample"; InOutState.Closed = true; return Result; }
                Fraction = (Seconds - FromSeconds) / Duration;
            }
            if (Fraction <= LastFraction || Fraction > 1.0)
            { Result.Failure = "Evaluated sample fractions are not ordered"; InOutState.Closed = true; return Result; }

            auto Step = FMars_Crawler_LongLimbSweepStep();
            Step.TargetFrom = Math::Lerp(TargetFrom, TargetTo, LastFraction);
            Step.TargetTo = Math::Lerp(TargetFrom, TargetTo, Fraction);
            const auto Validation = utils_crawler_limb_sweep::Make_Interval(LastLimb, NextLimb,
                InOutState.Spec.SegmentLengths, InOutState.Spec.SegmentRadii, InOutState.Spec.Sweep, Step.Spheres);
            if (Validation.IsValid() == false || Step.Spheres.Num() > InOutState.Spec.MaxSpheresPerReceipt - SphereCount)
            { Result.Failure = "Long-limb geometry is invalid or exceeds its query budget"; InOutState.Closed = true; return Result; }
            SphereCount += Step.Spheres.Num();
            Result.Steps.Add(Step);
            LastLimb = NextLimb;
            LastFraction = Fraction;
        }

        InOutState.LastAcceptedLimb = Current;
        InOutState.LastAcceptedSubjectRevision = Revision;
        Result.Valid = true;
        return Result;
    }
}
