namespace utils_hand_bob
{
    // InNode is the scene node the bob drives (its offset is rewritten every frame); the owning actor must be an
    // ACharacter. Only a locally controlled character is animated.
    void Add(FCk_Handle_SceneNode& InNode, FMars_HandBob_Spec InSpec)
    {
        auto Params = FMars_Fragment_HandBob_Params();
        Params.Spec = InSpec;

        InNode.Add_Fragment(FMars_Feature_HandBob());
        InNode.Add_Fragment(Params);
        InNode.Add_Fragment(FMars_Fragment_HandBob());
    }

    bool Has(const FCk_Handle& InHandle)
    {
        return InHandle.Has_Fragment(FMars_Feature_HandBob);
    }

    // Free-hand arm swing for this frame, in the node's frame. Zero when the node has no HandBob.
    FVector Get_ArmSwing_Right(const FCk_Handle& InHandle)
    {
        return Make_ArmSwing(InHandle, 1.0f);
    }

    FVector Get_ArmSwing_Left(const FCk_Handle& InHandle)
    {
        return Make_ArmSwing(InHandle, -1.0f);
    }

    FVector Make_ArmSwing(const FCk_Handle& InHandle, float32 InSide)
    {
        if (Has(InHandle) == false)
        { return FVector::ZeroVector; }

        const auto& Spec = InHandle.Get_Fragment(FMars_Fragment_HandBob_Params).Spec;
        const auto Swing = InHandle.Get_Fragment(FMars_Fragment_HandBob).ArmSwing * InSide;
        return FVector(Spec.ArmSwingCm * Swing, 0.0, Spec.ArmSwingLiftCm * Math::Max(Swing, 0.0f));
    }

    // Shared offset of the bob node (stride bob + breath + vertical spring).
    FTransform Make_NodeOffset(const FMars_HandBob_Spec& InSpec, const FMars_Fragment_HandBob& InState)
    {
        const auto Step = Math::Abs(Math::Sin(InState.Phase));
        const auto Sway = Math::Sin(InState.Phase);
        const auto Breath = InSpec.BreathPeriodSeconds > KINDA_SMALL_NUMBER
            ? Math::Sin(2.0 * PI * InState.BreathTime / InSpec.BreathPeriodSeconds) * InSpec.BreathCm * (1.0 - InState.Amount)
            : 0.0;

        const auto Location = FVector(
            0.0,
            InSpec.LateralCm * Sway * InState.Amount,
            -InSpec.VerticalCm * Step * InState.Amount + Breath + InState.SpringOffset);

        const auto Rotation = FRotator(
            -InSpec.PitchDeg * Step * InState.Amount,
            0.0,
            InSpec.RollDeg * Sway * InState.Amount);

        return FTransform(Rotation, Location, FVector::OneVector);
    }
}
