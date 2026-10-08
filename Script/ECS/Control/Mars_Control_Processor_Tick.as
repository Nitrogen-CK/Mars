// The pulled handle: a damped spring drags Alpha toward Pull, the Mover shows it, and crossing EngageAlpha in the pull's
// direction ends the manipulation and the CkInteraction (Succeeded) - the Interactable's Engage chain then flips the
// control, exactly as an Instant or Timed completion would. If that interaction finishes Failed instead (a cancel racing
// the end), nothing engages and the handle settles back from the threshold. A grip begun OnRelease has no threshold: the
// handle keeps following the pull inside [0, 1] until EndManipulation.
class UMars_Processor_Control_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    // A hitch must not blow the spring up.
    private const float32 k_MaxStepSeconds = 0.1f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
        Query.Require(FMars_Tag_Control_Manipulating);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Control& InState)
    {
        auto Self = InHandle.As_Control();
        const auto& Tuning = Self.Get_Fragment(FMars_Fragment_Control_Params).Manipulation;

        const auto DeltaSeconds = Math::Min(float32(InDeltaT.Get_Seconds()), k_MaxStepSeconds);

        // Semi-implicit Euler, with the travel's ends as hard stops.
        auto Manipulation = InState.Manipulation.GetValue();
        const auto Acceleration = Tuning.Stiffness * (Manipulation.Pull - Manipulation.Alpha) - Tuning.Damping * Manipulation.Velocity;
        Manipulation.Velocity += Acceleration * DeltaSeconds;
        Manipulation.Alpha += Manipulation.Velocity * DeltaSeconds;
        if (Manipulation.Alpha < 0.0f)
        {
            Manipulation.Alpha = 0.0f;
            Manipulation.Velocity = 0.0f;
        }
        else if (Manipulation.Alpha > 1.0f)
        {
            Manipulation.Alpha = 1.0f;
            Manipulation.Velocity = 0.0f;
        }
        InState.Manipulation = Manipulation;

        const auto Alpha = Manipulation.Alpha;

        auto Mover = InState.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_Scrub(FMars_Request_Mover_Scrub(Alpha)); }

        const auto Direction = Self.Get_PullDirection();
        const auto Progress = utils_control::Get_ProgressTowardEngage(Direction, Alpha, Tuning.EngageAlpha);
        if (Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(Self, Progress); }

        if (Manipulation.Completion == EMars_Control_ManipulationCompletion::OnRelease)
        { return; }

        if (utils_control::Get_HasCrossedEngage(Direction, Alpha, Tuning.EngageAlpha) == false)
        { return; }

        // A lever's handle is carried the rest of the way by the Engage's MoveTo; a returns-to-rest handle springs back now
        // (the Mover drains Scrub before Settle, so the tween starts from this frame's alpha).
        auto Interaction = Manipulation.Interaction;
        InState.Manipulation.Reset();
        Self.Request_TryRemove(FMars_Tag_Control_Manipulating);

        if (Self.Get_ReturnsToRest() && ck::IsValid(Mover))
        { Mover.Request_Settle(); }

        if (Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, EMars_Control_Grip::Released); }

        if (Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(Self, 0.0f); }

        // The interaction was cancelled before the threshold: nothing is left to complete.
        if (ck::Is_NOT_Valid(Interaction))
        { return; }

        utils_interaction::BindTo_OnInteractionFinished(Interaction,
            FCk_Delegate_Interaction_OnInteractionFinished(this, n"OnThresholdInteractionFinished"),
            ECk_Signal_BindingPolicy::FireIfPayloadInFlightThisFrame,
            ECk_Signal_PostFireBehavior::Unbind);
        utils_interaction::Request_EndInteraction(Interaction, FCk_Request_Interaction_EndInteraction(ECk_SucceededFailed::Succeeded));
    }

    // A Failed finish engages nothing, so the handle would rest at the threshold: settle it back to the current target
    // pose - unless a re-grip already owns the handle.
    UFUNCTION()
    private void OnThresholdInteractionFinished(FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (InResult == ECk_SucceededFailed::Succeeded)
        { return; }

        // The control's target, unless it is being torn down.
        auto TargetEntity = utils_interaction::Get_InteractionTarget(InInteraction);
        if (ck::Is_NOT_Valid(TargetEntity))
        { return; }

        auto Target = TargetEntity.As_InteractTarget();
        auto Control = Target.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner.As_Control();
        if (Control.Get_IsManipulating())
        { return; }

        auto Mover = Control.Get_Mover();
        if (ck::IsValid(Mover))
        { Mover.Request_Settle(); }
    }
}
