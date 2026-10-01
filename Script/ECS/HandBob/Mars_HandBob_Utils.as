namespace constants_hand_bob
{
    const float32 k_SpringStepSeconds = 1.0f / 120.0f;
    const float32 k_MaxSpringFrameSeconds = 0.1f;

    // A landing never pushes the hands further than this; beyond it the spring has diverged.
    const float32 k_MaxSpringOffsetCm = 100.0f;
}

namespace utils_hand_bob
{
    // InNode is the scene node the bob drives (HandBob owns its offset); the owning actor must be an ACharacter. Only a
    // locally controlled character is animated (TryGet_LocalCharacter).
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

    // The character whose first-person hands InHandle belongs to (its owning actor, walked up the entity tree), when
    // this machine controls it. Null for server copies, remote proxies and entities with no character: their hands are
    // never shown, so nothing advances them.
    ACharacter TryGet_LocalCharacter(const FCk_Handle& InHandle)
    {
        auto Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InHandle));
        if (ck::Is_NOT_Valid(Character) || Character.IsLocallyControlled() == false)
        { return nullptr; }

        return Character;
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

    // Advances the stride, breath and landing spring by InInput.DeltaSeconds (> 0). Non-finite input ensures and puts
    // the bob back at rest; a spring that went non-finite or ran away ensures and is re-seeded at rest.
    void Advance(const FMars_HandBob_Spec& InSpec, FMars_Fragment_HandBob& InOutState, const FMars_HandBob_Input& InInput)
    {
        const auto InDeltaSeconds = InInput.DeltaSeconds;
        const auto IsInputFinite = Math::IsFinite(InInput.GroundSpeed) && Math::IsFinite(InInput.VerticalSpeed);
        if (ck::EnsureIfNot(IsInputFinite,
            f"[HandBob] Non-finite locomotion input (ground speed [{InInput.GroundSpeed}], vertical speed [{InInput.VerticalSpeed}]) - the bob rests this frame"))
        {
            Reset_ToRest(InOutState);
            return;
        }

        // Stride: amplitude follows ground speed, phase advances with it (so slow steps are slow, sprint is quick).
        const auto SpeedRatio = InSpec.ReferenceSpeed > KINDA_SMALL_NUMBER ? InInput.GroundSpeed / InSpec.ReferenceSpeed : 0.0;
        auto TargetAmount = float32(Math::Min(SpeedRatio, float(InSpec.MaxAmountScale)));
        if (InInput.IsCrouched)
        { TargetAmount *= InSpec.CrouchScale; }

        const auto AmountAlpha = float32(1.0 - Math::Exp(-InSpec.AmountInterpSpeed * InDeltaSeconds));
        InOutState.Amount += (TargetAmount - InOutState.Amount) * AmountAlpha;
        InOutState.Phase = float32(Math::Fmod(InOutState.Phase + 2.0 * PI * InSpec.StridesPerSecond * Math::Max(SpeedRatio, 0.35) * InDeltaSeconds, 2.0 * PI));
        InOutState.BreathTime = float32(Math::Fmod(float(InOutState.BreathTime + InDeltaSeconds), float(Math::Max(InSpec.BreathPeriodSeconds, 0.01f))));

        // Landing: a downward kick on the spring, which then bounces back to rest.
        if (InOutState.WasFalling && InInput.IsFalling == false)
        {
            const auto Impact = Math::Max(-InOutState.LastVerticalSpeed, 0.0f);
            InOutState.SpringVelocity -= Math::Min(Impact * InSpec.LandKickPerImpactSpeed, InSpec.MaxLandKick);
        }
        InOutState.WasFalling = InInput.IsFalling;
        InOutState.LastVerticalSpeed = InInput.VerticalSpeed;

        // No spring helper is bound for AngelScript (FMath::SpringDamper is not): fixed substeps of semi-implicit Euler,
        // so a hitch or a throttled editor frame cannot blow the spring up.
        const auto Omega = 2.0f * float32(PI) * InSpec.SpringFrequencyHz;
        auto Remaining = Math::Min(InDeltaSeconds, constants_hand_bob::k_MaxSpringFrameSeconds);
        while (Remaining > 0.0f)
        {
            const auto Step = Math::Min(Remaining, constants_hand_bob::k_SpringStepSeconds);
            const auto Accel = -Omega * Omega * InOutState.SpringOffset - 2.0f * InSpec.SpringDampingRatio * Omega * InOutState.SpringVelocity;
            InOutState.SpringVelocity += Accel * Step;
            InOutState.SpringOffset += InOutState.SpringVelocity * Step;
            Remaining -= Step;
        }

        const auto IsSpringSane = Math::IsFinite(InOutState.SpringOffset) && Math::IsFinite(InOutState.SpringVelocity)
            && Math::Abs(InOutState.SpringOffset) <= constants_hand_bob::k_MaxSpringOffsetCm;
        if (ck::EnsureIfNot(IsSpringSane,
            f"[HandBob] Landing spring diverged (offset [{InOutState.SpringOffset}], velocity [{InOutState.SpringVelocity}]) - re-seeded at rest"))
        {
            InOutState.SpringOffset = 0.0f;
            InOutState.SpringVelocity = 0.0f;
        }

        InOutState.ArmSwing = Math::Sin(InOutState.Phase) * InOutState.Amount;
    }

    void Reset_ToRest(FMars_Fragment_HandBob& InOutState)
    {
        InOutState = FMars_Fragment_HandBob();
    }

    // Shared offset of the bob node (stride bob + breath + landing spring). Breath fades out as the stride fades in
    // and never inverts when Amount passes 1 (a sprint).
    FTransform Make_NodeOffset(const FMars_HandBob_Spec& InSpec, const FMars_Fragment_HandBob& InState)
    {
        const auto Step = Math::Abs(Math::Sin(InState.Phase));
        const auto Sway = Math::Sin(InState.Phase);
        const auto Breath = InSpec.BreathPeriodSeconds > KINDA_SMALL_NUMBER
            ? Math::Sin(2.0 * PI * InState.BreathTime / InSpec.BreathPeriodSeconds) * InSpec.BreathCm * Math::Max(1.0 - InState.Amount, 0.0)
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
