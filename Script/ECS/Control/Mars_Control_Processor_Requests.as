// Drains SetActive -> Engage -> EndManipulation -> BeginManipulation -> Nudges (see FMars_Fragment_Control_Requests).
// SetActive and Engage apply on the authority only: a client's are dropped (its engage arrives as Cue.Mars.Control.Engage).
// The grip requests apply wherever a grip may begin (Get_MayGripHere: the authority, or a client whose control's entity
// replicates) and are dropped elsewhere. A pending engage on a client begins no grip until it clears.
class UMars_Processor_Control_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Control_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Control_Requests& InRequests,
                       FMars_Fragment_Control& InState)
    {
        auto Self = InHandle.As_Control();

        if (Self.Get_MayGripHere() == false)
        {
            InHandle.Request_TryRemove(FMars_Fragment_Control_Requests);
            return;
        }

        // Off authority only the grip applies; the ledger is the authority's.
        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        const auto HasEngage = HasAuthority && InRequests.EngageRequest.IsSet();
        const auto HasSetActive = HasAuthority && InRequests.SetActiveRequest.IsSet();
        auto SetActiveValue = false;
        if (HasSetActive)
        { SetActiveValue = InRequests.SetActiveRequest.GetValue().Activation == EMars_Control_Activation::Active; }

        const auto HasEndManipulation = InRequests.EndManipulationRequest.IsSet();
        const auto HasBeginManipulation = InRequests.BeginManipulationRequest.IsSet();
        auto BeginManipulationRequest = FMars_Request_Control_BeginManipulation();
        if (HasBeginManipulation)
        { BeginManipulationRequest = InRequests.BeginManipulationRequest.GetValue(); }

        TArray<FMars_Request_Control_Nudge> NudgeRequests = InRequests.NudgeRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Control_Requests);

        const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);
        auto& Local = Self.Get_Fragment(FMars_Fragment_Control_Local);
        const auto WasActive = InState.IsActive;
        auto NewActive = WasActive;

        if (HasSetActive)
        {
            if (SetActiveValue == false)
            { DestroyReleaseTimer(Local); }
            else if (Params.Behavior == EMars_Control_Behavior::Momentary)
            { ArmReleaseTimer(Self, Local, Params.ActiveSeconds); }

            NewActive = SetActiveValue;
        }

        if (HasEngage)
        {
            if (Params.Behavior == EMars_Control_Behavior::Toggle)
            { NewActive = NewActive == false; }
            else
            {
                NewActive = true;
                ArmReleaseTimer(Self, Local, Params.ActiveSeconds);
            }

            InState.Engagements += 1;
        }

        const auto Changed = NewActive != WasActive;
        if (Changed)
        {
            InState.IsActive = NewActive;

            // A returns-to-rest handle is not a state display: it springs back after every pull.
            auto Mover = Local.Mover;
            if (ck::IsValid(Mover) && Self.Get_ReturnsToRest() == false)
            { Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(NewActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start)); }
        }

        if (Changed || HasEngage)
        { InHandle.Request_MarkReplicationDirty(FMars_Fragment_Control); }

        // Not manipulating: the threshold already ended it, and a Settle here would fight the Engage's MoveTo.
        const auto Ended = HasEndManipulation && Local.Manipulation.IsSet();
        if (Ended)
        { EndManipulation(Self, Local); }

        auto Began = false;
        if (HasBeginManipulation)
        { Began = BeginManipulation(Self, Local, BeginManipulationRequest); }

        // FreeTurn: the drain's pull degrees, broadcast after the grip edges below.
        auto TurnDegrees = 0.0f;
        if (Local.Manipulation.IsSet())
        { TurnDegrees = ApplyNudges(Self, Local, NudgeRequests); }

        if (HasEngage && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnEngaged.Broadcast(Self); }

        if (Changed && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        {
            const auto Activation = NewActive ? EMars_Control_Activation::Active : EMars_Control_Activation::Inactive;
            Self.Get_Fragment(FMars_Fragment_Control_Signals).OnActiveChanged.Broadcast(Self, Activation);
        }

        if (Ended && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, EMars_Control_Grip::Released); }

        if (Ended && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(Self, 0.0f); }

        if (Began && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, EMars_Control_Grip::Gripped); }

        if (TurnDegrees != 0.0f && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnTurned.Broadcast(Self, TurnDegrees); }
    }

    // Lets go before the threshold: the handle settles back to the current target pose from wherever it is.
    private void EndManipulation(FCk_Handle_Control& InControl, FMars_Fragment_Control_Local& InState)
    {
        InState.Manipulation.Reset();
        InControl.Request_TryRemove(FMars_Tag_Control_Manipulating);

        auto Mover = InState.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_Settle(FMars_Request_Mover_Settle()); }
    }

    // Returns false while a pending engage stands (not an error: the grip is asked again once it clears), when the control
    // is not ManuallyCompleted, or is a Walk control without a valid Puller (both ensure). The
    // grip starts where the handle stands (without a Mover: at the end the pull runs from), and the scrub stops an in-flight
    // engage tween so the hand owns the handle. A Walk grip records the puller's horizontal distance now: the pull is what
    // it gains from here.
    private bool BeginManipulation(
        FCk_Handle_Control& InControl,
        FMars_Fragment_Control_Local& InState,
        const FMars_Request_Control_BeginManipulation& InRequest)
    {
        // A grip now would seed at the threshold and read the direction the engage is about to change.
        if (InState.PendingEngage.IsSet())
        { return false; }

        const auto IsManuallyCompleted =
            InControl.Get_CompletionPolicy() == ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        if (ck::EnsureIfNot(IsManuallyCompleted, f"[Control] [{InControl.ToString()}] is not ManuallyCompleted; BeginManipulation ignored"))
        { return false; }

        const auto IsWalk = InControl.Get_PullSource() == EMars_Control_PullSource::Walk;
        if (IsWalk && ck::EnsureIfNot(ck::IsValid(InRequest.Puller) && ck::IsValid(InControl.H().As_Transform(ECk_SanityCheck::UnChecked)),
            f"[Control] [{InControl.ToString()}] is a Walk control: BeginManipulation needs a valid Puller and a control with a transform; ignored"))
        { return false; }

        auto Mover = InState.Mover;
        const auto HasMover = ck::IsValid(Mover);

        const auto RestAlpha = InControl.Get_PullDirection() == EMars_Control_PullDirection::TowardStart ? 1.0f : 0.0f;

        // A FreeTurn grip has no threshold to cross, whatever the request asked.
        const auto IsFreeTurn = InControl.Get_IsFreeTurn();

        auto Manipulation = FMars_Control_Manipulation();
        Manipulation.Interaction = InRequest.Interaction;
        Manipulation.Completion = IsFreeTurn ? EMars_Control_ManipulationCompletion::OnRelease : InRequest.Completion;
        Manipulation.Alpha = HasMover ? Mover.Get_Alpha() : RestAlpha;
        Manipulation.Pull = Manipulation.Alpha;
        if (IsWalk)
        {
            Manipulation.Puller = InRequest.Puller;
            Manipulation.WalkStartCm = InControl.Get_HorizontalDistanceTo(InRequest.Puller);
        }
        InState.Manipulation = Manipulation;

        if (InControl.Has_Fragment(FMars_Tag_Control_Manipulating) == false)
        { InControl.Add_Fragment(FMars_Tag_Control_Manipulating()); }

        if (HasMover)
        { Mover.Request_Scrub(FMars_Request_Mover_Scrub(Manipulation.Alpha)); }

        return true;
    }

    // Returns the drain's degrees for a FreeTurn control (its pull is not integrated), 0 for Travel. A Walk control's pull is
    // the puller's distance (UMars_Processor_Control_Tick): its nudges change nothing. Not an error: the player's task just
    // sends none.
    private float32 ApplyNudges(
        FCk_Handle_Control& InControl,
        FMars_Fragment_Control_Local& InState,
        const TArray<FMars_Request_Control_Nudge>& InNudges)
    {
        if (InNudges.IsEmpty())
        { return 0.0f; }

        auto PullDegrees = 0.0f;
        for (const auto& Nudge : InNudges)
        { PullDegrees += Nudge.PullDegrees; }

        if (InControl.Get_IsFreeTurn())
        { return PullDegrees; }

        if (InControl.Get_PullSource() == EMars_Control_PullSource::Walk)
        { return 0.0f; }

        const auto AlphaPerDegree = InControl.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.AlphaPerDegree;
        auto Manipulation = InState.Manipulation.GetValue();
        Manipulation.Pull = Math::Clamp(Manipulation.Pull + PullDegrees * AlphaPerDegree, 0.0f, 1.0f);
        InState.Manipulation = Manipulation;
        return 0.0f;
    }

    private void ArmReleaseTimer(FCk_Handle_Control& InControl, FMars_Fragment_Control_Local& InState, float32 InActiveSeconds)
    {
        DestroyReleaseTimer(InState);

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InActiveSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InControl, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnReleaseTimerDone")); }
        InState.ReleaseTimer = Timer;
    }

    private void DestroyReleaseTimer(FMars_Fragment_Control_Local& InState)
    {
        if (ck::IsValid(InState.ReleaseTimer))
        { utils_entity_lifetime::Request_DestroyEntity(InState.ReleaseTimer); }

        InState.ReleaseTimer = FCk_Handle_Timer();
    }

    UFUNCTION()
    private void OnReleaseTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The control is going away with its timer.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Control = Owner.As_Control();

        // A timer replaced by a re-engage can still finish in the frame it was destroyed.
        const auto& State = Control.Get_Fragment(FMars_Fragment_Control_Local);
        if (State.ReleaseTimer != InTimer)
        { return; }

        Control.Request_SetActive(FMars_Request_Control_SetActive(EMars_Control_Activation::Inactive));
    }
}
