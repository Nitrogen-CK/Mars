// Picks what each eye node looks at, every pass: every entity inside the sense trigger resolves to its owner (ck::Ctx)
// and that owner's AimPoint attach point; the nearest one inside [MinRangeCm, RangeCm] and the cone around the eye
// node's +X wins, except that the current target is kept until a challenger is closer by SwitchCloserRatio of its
// distance. A sensed owner without the aim point is reported once while it stays sensed (and again if it leaves and
// returns). OnTargetChanged fires after Target and AimYawPitchDeg are written.
class UMars_Processor_Gaze_Select : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Gaze);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Gaze& InState)
    {
        if (ck::EnsureIfNot(ck::IsValid(InState.Sense), f"[Gaze] [{InHandle.ToString()}] has no sense trigger - nothing to look at"))
        { return; }

        const auto& Tuning = InHandle.Get_Fragment(FMars_Fragment_Gaze_Params).Tuning;
        const auto OwnContext = ck::Ctx(InHandle);
        const auto EyeWorld = utils_transform::Get_EntityCurrentTransform(InHandle.As_Transform());

        auto Nearest = FCk_Handle_Transform();
        auto NearestDistance = 0.0;
        auto NearestLocal = FVector::ZeroVector;

        auto CurrentIsEligible = false;
        auto CurrentDistance = 0.0;
        auto CurrentLocal = FVector::ZeroVector;

        auto OwnersWithoutAim = TArray<FCk_Handle>();

        for (auto Entity : InState.Sense.Get_EntitiesInside())
        {
            // A probe under the gaze's own owner (its own body) is never something to look at.
            auto Owner = ck::Ctx(Entity);
            if (Owner == OwnContext)
            { continue; }

            const auto AimNode = DoGet_AimNode(Owner, Tuning.AimPoint);
            if (ck::Is_NOT_Valid(AimNode))
            {
                OwnersWithoutAim.AddUnique(Owner);
                if (InState.ReportedOwnersWithoutAim.Contains(Owner) == false)
                {
                    InState.ReportedOwnersWithoutAim.Add(Owner);
                    ck::EnsureIfNot(false,
                        f"[Gaze] [{InHandle.ToString()}] detected [{Owner.ToString()}], which publishes no [{Tuning.AimPoint.ToString()}] attach point - not a look target");
                }
                continue;
            }

            const auto AimWorld = utils_transform::Get_EntityCurrentTransform(AimNode);
            const auto Local = EyeWorld.InverseTransformPositionNoScale(AimWorld.GetLocation());
            const auto Distance = Local.Size();
            if (Distance <= KINDA_SMALL_NUMBER || Distance < Tuning.MinRangeCm || Distance > Tuning.RangeCm)
            { continue; }

            const auto AngleToForwardDeg = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Local.X / Distance, -1.0, 1.0)));
            if (AngleToForwardDeg > Tuning.ConeHalfAngleDeg)
            { continue; }

            if (AimNode == InState.Target)
            {
                CurrentIsEligible = true;
                CurrentDistance = Distance;
                CurrentLocal = Local;
            }

            if (ck::Is_NOT_Valid(Nearest) || Distance < NearestDistance)
            {
                Nearest = AimNode;
                NearestDistance = Distance;
                NearestLocal = Local;
            }
        }

        // An owner that left the sense trigger, was destroyed or now publishes the aim point is reported again next
        // time.
        for (int32 Index = InState.ReportedOwnersWithoutAim.Num() - 1; Index >= 0; --Index)
        {
            const auto& Reported = InState.ReportedOwnersWithoutAim[Index];
            if (ck::Is_NOT_Valid(Reported) || OwnersWithoutAim.Contains(Reported) == false)
            { InState.ReportedOwnersWithoutAim.RemoveAt(Index); }
        }

        // A challenger at least SwitchCloserRatio closer takes over; anything less keeps the current target.
        auto Chosen = Nearest;
        auto ChosenLocal = NearestLocal;
        if (CurrentIsEligible && NearestDistance > CurrentDistance * (1.0 - Tuning.SwitchCloserRatio))
        {
            Chosen = InState.Target;
            ChosenLocal = CurrentLocal;
        }

        const auto Previous = InState.Target;
        InState.Target = Chosen;
        InState.AimYawPitchDeg = ck::IsValid(Chosen) ? DoMake_YawPitchDeg(ChosenLocal) : FVector2D::ZeroVector;

        if (Previous == Chosen)
        { return; }

        auto Gaze = InHandle.As_Gaze();
        if (Gaze.Has_Fragment(FMars_Fragment_Gaze_Signals))
        { Gaze.Get_Fragment(FMars_Fragment_Gaze_Signals).OnTargetChanged.Broadcast(Gaze, Previous, Chosen); }
    }

    // Invalid when InOwner has no AttachPoints or publishes nothing under InAimPoint.
    private FCk_Handle_Transform DoGet_AimNode(const FCk_Handle& InOwner, FGameplayTag InAimPoint) const
    {
        if (InOwner.Has_Fragment(FMars_Feature_AttachPoints) == false)
        { return FCk_Handle_Transform(); }

        return InOwner.As_AttachPoints().Get_AttachPoint(InAimPoint);
    }

    // InLocal is in the eye node's frame (X forward, Y right, Z up).
    private FVector2D DoMake_YawPitchDeg(const FVector& InLocal) const
    {
        const auto Yaw = Math::RadiansToDegrees(Math::Atan2(InLocal.Y, InLocal.X));
        const auto Pitch = Math::RadiansToDegrees(Math::Atan2(InLocal.Z, Math::Sqrt(InLocal.X * InLocal.X + InLocal.Y * InLocal.Y)));
        return FVector2D(Yaw, Pitch);
    }
}
