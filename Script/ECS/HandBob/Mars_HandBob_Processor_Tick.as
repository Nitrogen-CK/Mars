const float32 SpringStepSeconds = 1.0f / 120.0f;
const float32 MaxSpringFrameSeconds = 0.1f;

class UMars_Processor_HandBob_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HandBob);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_HandBob& InState)
    {
        // First-person presentation only: remote copies of the character never render their hands.
        auto Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InHandle));
        if (Character == nullptr || Character.IsLocallyControlled() == false)
        { return; }

        const auto& Spec = InHandle.Get_Fragment(FMars_Fragment_HandBob_Params).Spec;
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        if (DeltaSeconds <= 0.0f)
        { return; }

        const auto Movement = Character.CharacterMovement;
        const auto Velocity = Character.GetVelocity();
        const auto IsFalling = ck::IsValid(Movement) && Movement.IsFalling();
        const auto GroundSpeed = IsFalling ? 0.0 : Velocity.Size2D();

        // Stride: amplitude follows ground speed, phase advances with it (so slow steps are slow, sprint is quick).
        const auto SpeedRatio = Spec.ReferenceSpeed > KINDA_SMALL_NUMBER ? GroundSpeed / Spec.ReferenceSpeed : 0.0;
        auto TargetAmount = float32(Math::Min(SpeedRatio, float(Spec.MaxAmountScale)));
        if (Character.bIsCrouched)
        { TargetAmount *= Spec.CrouchScale; }

        const auto AmountAlpha = float32(1.0 - Math::Exp(-Spec.AmountInterpSpeed * DeltaSeconds));
        InState.Amount += (TargetAmount - InState.Amount) * AmountAlpha;
        InState.Phase = float32(Math::Fmod(InState.Phase + 2.0 * PI * Spec.StridesPerSecond * Math::Max(SpeedRatio, 0.35) * DeltaSeconds, 2.0 * PI));
        InState.BreathTime = float32(Math::Fmod(float(InState.BreathTime + DeltaSeconds), float(Math::Max(Spec.BreathPeriodSeconds, 0.01f))));

        // Vertical spring: hands float up while falling, get kicked down on landing, then bounce back.
        const auto VerticalSpeed = float32(Velocity.Z);
        auto SpringTarget = 0.0f;
        if (IsFalling)
        { SpringTarget = Math::Clamp(-VerticalSpeed * Spec.AirLiftPerFallSpeed, -Spec.MaxAirLiftCm, Spec.MaxAirLiftCm); }

        if (InState.WasFalling && IsFalling == false)
        {
            const auto Impact = Math::Max(-InState.LastVerticalSpeed, 0.0f);
            InState.SpringVelocity -= Math::Min(Impact * Spec.LandKickPerImpactSpeed, Spec.MaxLandKick);
        }
        InState.WasFalling = IsFalling;
        InState.LastVerticalSpeed = VerticalSpeed;

        // Fixed substeps (semi-implicit Euler) so a hitch or a throttled editor frame cannot blow the spring up.
        const auto Omega = 2.0f * float32(PI) * Spec.SpringFrequencyHz;
        auto Remaining = Math::Min(DeltaSeconds, MaxSpringFrameSeconds);
        while (Remaining > 0.0f)
        {
            const auto Step = Math::Min(Remaining, SpringStepSeconds);
            const auto Accel = Omega * Omega * (SpringTarget - InState.SpringOffset) - 2.0f * Spec.SpringDampingRatio * Omega * InState.SpringVelocity;
            InState.SpringVelocity += Accel * Step;
            InState.SpringOffset += InState.SpringVelocity * Step;
            Remaining -= Step;
        }

        // NaN compares unequal to itself; any non-finite or runaway value re-seeds the spring at rest.
        if (InState.SpringOffset != InState.SpringOffset || InState.SpringVelocity != InState.SpringVelocity
            || Math::Abs(InState.SpringOffset) > 100.0f)
        {
            InState.SpringOffset = 0.0f;
            InState.SpringVelocity = 0.0f;
        }

        // Arm swing for free hands (read by the first-person hand targets).
        InState.ArmSwing = Math::Sin(InState.Phase) * InState.Amount;

        auto Node = utils_scene_node::DoCastChecked(InHandle);
        utils_scene_node::Request_UpdateOffset(Node,
            FCk_Request_SceneNode_UpdateRelativeTransform(utils_hand_bob::Make_NodeOffset(Spec, InState)));
    }
}
