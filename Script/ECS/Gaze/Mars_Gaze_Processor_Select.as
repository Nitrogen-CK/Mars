// Picks what each eye node looks at, every pass. The current target is kept until a challenger is closer by
// SwitchCloserRatio of its distance. A sensed owner without the aim point is reported once while it stays sensed (and
// again if it leaves and returns). OnTargetChanged fires after Target and AimYawPitchDeg are written.
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

        const auto& Spec = InHandle.Get_Fragment(FMars_Fragment_Gaze_Params).Spec;
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
            auto Owner = ck::Ctx(Entity);
            const auto AimNode = DoGet_AimNode(Owner, Spec.AimPoint);
            if (ck::Is_NOT_Valid(AimNode))
            {
                OwnersWithoutAim.AddUnique(Owner);
                if (InState.ReportedOwnersWithoutAim.Contains(Owner) == false)
                {
                    InState.ReportedOwnersWithoutAim.Add(Owner);
                    ck::EnsureIfNot(false,
                        f"[Gaze] [{InHandle.ToString()}] detected [{Owner.ToString()}], which publishes no [{Spec.AimPoint.ToString()}] attach point - not a look target");
                }
                continue;
            }

            const auto AimWorld = utils_transform::Get_EntityCurrentTransform(AimNode);
            const auto Local = EyeWorld.InverseTransformPositionNoScale(AimWorld.GetLocation());
            const auto Distance = Local.Size();
            if (Distance <= KINDA_SMALL_NUMBER || Distance < Spec.MinRangeCm || Distance > Spec.RangeCm)
            { continue; }

            const auto AngleToForwardDeg = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Local.X / Distance, -1.0, 1.0)));
            if (AngleToForwardDeg > Spec.ConeHalfAngleDeg)
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

        auto Chosen = Nearest;
        auto ChosenLocal = NearestLocal;
        if (CurrentIsEligible && NearestDistance > CurrentDistance * (1.0 - Spec.SwitchCloserRatio))
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
        const auto AttachPoints = InOwner.As_AttachPoints(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(AttachPoints))
        { return FCk_Handle_Transform(); }

        return AttachPoints.Get_AttachPoint(InAimPoint);
    }

    // InLocal is in the eye node's frame (X forward, Y right, Z up).
    private FVector2D DoMake_YawPitchDeg(const FVector& InLocal) const
    {
        const auto Yaw = Math::RadiansToDegrees(Math::Atan2(InLocal.Y, InLocal.X));
        const auto Pitch = Math::RadiansToDegrees(Math::Atan2(InLocal.Z, Math::Sqrt(InLocal.X * InLocal.X + InLocal.Y * InLocal.Y)));
        return FVector2D(Yaw, Pitch);
    }
}
