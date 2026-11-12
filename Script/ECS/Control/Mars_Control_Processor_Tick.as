// The pulled handle: a damped spring drags Alpha toward Pull, the Mover shows it, and crossing EngageAlpha in the pull's
// direction ends the manipulation and the CkInteraction (Succeeded) - the Interactable's Engage chain then flips the
// control, exactly as an Instant or Timed completion would. If that interaction finishes Failed instead (a cancel racing
// the end), nothing engages and the handle settles back from the threshold. A grip begun OnRelease has no threshold: the
// handle keeps following the pull inside [0, 1] until EndManipulation. A Walk control's Pull is set here each tick from the
// puller's horizontal distance gained since the grip (over WalkCm, clamped); walking back lowers it and the spring follows.
// A Walk grip whose puller is gone ends as EndManipulation ends it; its interaction ends by its own teardown.
// It runs wherever a grip began: the authority, or a client whose control replicates (the Manipulating tag exists only
// there). A threshold crossed without authority also sets a pending engage: no grip begins until the ledger counts the
// engagement (UMars_Processor_Control_Setup clears it), and when utils_control::k_PendingEngageSeconds pass first the
// handle settles back from the threshold. Each grip ending here reports its end to the arbiter exactly once
// (utils_control::Request_GripFor): a lost puller, or a threshold whose interaction is already gone, reports LetGo; a
// threshold reports Cross when its interaction finishes Succeeded, LetGo when it finishes Failed. The pending engage keeps
// the gripper, so a refusal mirrored after the crossing (UMars_Processor_Control_GripMirror) clears it at once.
class UMars_Processor_Control_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Control_HandleRequests");

    // A hitch must not blow the spring up: the frame is capped, then integrated in substeps no longer than this. One
    // semi-implicit Euler step is only stable while Stiffness * dt^2 stays small; at the turnip bed's 400 / 40 a single
    // 0.08 s step carried alpha from 0.30 past the 0.97 threshold and popped the root on a hitch frame (PIE run-09).
    // 1/240 s keeps a stiffness of a few thousand well inside the stable range; a 0.1 s frame costs 24 cheap steps.
    private const float32 k_MaxStepSeconds = 0.1f;
    private const float32 k_MaxSubstepSeconds = 1.0f / 240.0f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
        Query.Require(FMars_Tag_Control_Manipulating);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Control& InState)
    {
        auto Self = InHandle.As_Control();
        auto& Local = Self.Get_Fragment(FMars_Fragment_Control_Local);

        // A FreeTurn grip has no handle travel: its pull leaves as OnTurned from the request drain.
        if (Self.Get_IsFreeTurn())
        { return; }

        const auto& Tuning = Self.Get_Fragment(FMars_Fragment_Control_Params).Manipulation;

        const auto DeltaSeconds = Math::Min(float32(InDeltaT.Get_Seconds()), k_MaxStepSeconds);

        auto Manipulation = Local.Manipulation.GetValue();

        if (Tuning.PullSource == EMars_Control_PullSource::Walk)
        {
            if (ck::Is_NOT_Valid(Manipulation.Puller))
            {
                EndWithoutPuller(Self, Local);
                return;
            }

            // TowardStart mirrors the travel, as the nudge integral does from its seeded alpha.
            const auto Gained = Math::Clamp((Self.Get_HorizontalDistanceTo(Manipulation.Puller) - Manipulation.WalkStartCm) / Tuning.WalkCm, 0.0f, 1.0f);
            Manipulation.Pull = Self.Get_PullDirection() == EMars_Control_PullDirection::TowardStart ? 1.0f - Gained : Gained;
        }

        // Semi-implicit Euler in substeps, with the travel's ends as hard stops.
        const auto Substeps = Math::Max(int32(Math::CeilToInt(DeltaSeconds / k_MaxSubstepSeconds)), 1);
        const auto SubstepSeconds = DeltaSeconds / float32(Substeps);
        for (int32 Substep = 0; Substep < Substeps; ++Substep)
        {
            const auto Acceleration = Tuning.Stiffness * (Manipulation.Pull - Manipulation.Alpha) - Tuning.Damping * Manipulation.Velocity;
            Manipulation.Velocity += Acceleration * SubstepSeconds;
            Manipulation.Alpha += Manipulation.Velocity * SubstepSeconds;
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
        }
        Local.Manipulation = Manipulation;

        const auto Alpha = Manipulation.Alpha;

        auto Mover = Local.Mover;
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
        const auto Gripper = Manipulation.Gripper;
        Local.Manipulation.Reset();
        Self.Request_TryRemove(FMars_Tag_Control_Manipulating);

        if (Self.Get_ReturnsToRest() && ck::IsValid(Mover))
        { Mover.Request_Settle(FMars_Request_Mover_Settle()); }

        if (Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, EMars_Control_Grip::Released); }

        if (Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(Self, 0.0f); }

        // Until the engage comes back, this machine's ledger still holds the direction the crossing is about to change.
        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            auto Pending = FMars_Control_PendingEngage();
            Pending.Engagements = InState.Engagements;
            Pending.Gripper = Gripper;
            Arm_PendingEngage(Self, Local, Pending);
        }

        // The interaction was cancelled before the threshold: nothing is left to complete, and the grip only lets go.
        if (ck::Is_NOT_Valid(Interaction))
        {
            utils_control::Request_GripFor(Self, Gripper, EMars_Control_GripVerb::LetGo);
            return;
        }

        utils_interaction::BindTo_OnInteractionFinished(Interaction,
            FCk_Delegate_Interaction_OnInteractionFinished(this, n"OnThresholdInteractionFinished"),
            ECk_Signal_BindingPolicy::FireIfPayloadInFlightThisFrame,
            ECk_Signal_PostFireBehavior::Unbind);
        utils_interaction::Request_EndInteraction(Interaction, FCk_Request_Interaction_EndInteraction(ECk_SucceededFailed::Succeeded));
    }

    // EndManipulation's end (UMars_Processor_Control_HandleRequests): the handle settles back, Released and progress 0.
    private void EndWithoutPuller(FCk_Handle_Control& InControl, FMars_Fragment_Control_Local& InState)
    {
        const auto Gripper = InState.Manipulation.GetValue().Gripper;
        InState.Manipulation.Reset();
        InControl.Request_TryRemove(FMars_Tag_Control_Manipulating);

        auto Mover = InState.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_Settle(FMars_Request_Mover_Settle()); }

        if (InControl.Has_Fragment(FMars_Fragment_Control_Signals))
        { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(InControl, EMars_Control_Grip::Released); }

        if (InControl.Has_Fragment(FMars_Fragment_Control_Signals))
        { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(InControl, 0.0f); }

        utils_control::Request_GripFor(InControl, Gripper, EMars_Control_GripVerb::LetGo);
    }

    // InPending carries the crossing's engagements and gripper; its timer is armed here.
    private void Arm_PendingEngage(FCk_Handle_Control& InControl, FMars_Fragment_Control_Local& InState, FMars_Control_PendingEngage InPending)
    {
        auto TimerSpec = FCk_Timer_Spec(FCk_Time(utils_control::k_PendingEngageSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InControl, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnPendingEngageTimerDone")); }

        auto Pending = InPending;
        Pending.Timer = Timer;
        InState.PendingEngage = Pending;
    }

    // The engage never came back (refused, or lost with the control): the handle settles back from the threshold.
    UFUNCTION()
    private void OnPendingEngageTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The control is going away with its timer.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Control = Owner.As_Control();
        auto& Local = Control.Get_Fragment(FMars_Fragment_Control_Local);

        // The mirrored engage already cleared it and destroyed this timer, which can still finish that frame.
        if (Local.PendingEngage.IsSet() == false || Local.PendingEngage.GetValue().Timer != InTimer)
        { return; }

        Local.PendingEngage.Reset();
        utils_entity_lifetime::Request_DestroyEntity(InTimer);

        auto Mover = Local.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_Settle(FMars_Request_Mover_Settle()); }
    }

    // The threshold's grip ends here: Succeeded reports Cross (the arbiter engages for it), Failed reports LetGo. A Failed
    // finish engages nothing, so the handle would rest at the threshold: settle it back to the current target pose - unless
    // a re-grip already owns the handle.
    UFUNCTION()
    private void OnThresholdInteractionFinished(FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        // The control's target, unless it is being torn down (its grip goes with it).
        auto TargetEntity = utils_interaction::Get_InteractionTarget(InInteraction);
        if (ck::Is_NOT_Valid(TargetEntity))
        { return; }

        auto Target = TargetEntity.As_InteractTarget();
        auto Control = Target.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner.As_Control();
        const auto Gripper = utils_interaction::Get_InteractionSource(InInteraction);
        const auto Verb = InResult == ECk_SucceededFailed::Succeeded ? EMars_Control_GripVerb::Cross : EMars_Control_GripVerb::LetGo;
        utils_control::Request_GripFor(Control, Gripper, Verb);

        if (InResult == ECk_SucceededFailed::Succeeded)
        { return; }

        if (Control.Get_IsManipulating())
        { return; }

        auto Mover = Control.Get_Mover();
        if (ck::IsValid(Mover))
        { Mover.Request_Settle(FMars_Request_Mover_Settle()); }
    }
}
