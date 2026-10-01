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

        const auto HasEngage = InRequests.EngageRequest.IsSet();
        const auto HasSetActive = InRequests.SetActiveRequest.IsSet();
        auto SetActiveValue = false;
        if (HasSetActive)
        { SetActiveValue = InRequests.SetActiveRequest.GetValue().Active; }

        const auto HasEndManipulation = InRequests.EndManipulationRequest.IsSet();
        const auto HasBeginManipulation = InRequests.BeginManipulationRequest.IsSet();
        auto BeginManipulationRequest = FMars_Request_Control_BeginManipulation();
        if (HasBeginManipulation)
        { BeginManipulationRequest = InRequests.BeginManipulationRequest.GetValue(); }

        TArray<FMars_Request_Control_Nudge> NudgeRequests = InRequests.NudgeRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Control_Requests);

        const auto& Params = Self.Get_Fragment(FMars_Fragment_Control_Params);
        const auto WasActive = InState.IsActive;
        auto NewActive = WasActive;

        if (HasSetActive)
        {
            if (SetActiveValue == false)
            { DestroyReleaseTimer(InState); }

            NewActive = SetActiveValue;
        }

        if (HasEngage)
        {
            if (Params.Behavior == EMars_Control_Behavior::Toggle)
            { NewActive = NewActive == false; }
            else
            {
                NewActive = true;
                ArmReleaseTimer(Self, InState, Params.ActiveSeconds);
            }
        }

        const auto Changed = NewActive != WasActive;
        if (Changed)
        {
            InState.IsActive = NewActive;

            auto Mover = InState.Mover;
            if (ck::IsValid(Mover))
            { Mover.Request_MoveTo(NewActive); }
        }

        // Not manipulating: the threshold already ended it, and a Settle here would fight the Engage's MoveTo.
        const auto Ended = HasEndManipulation && InState.Manipulation.IsActive;
        if (Ended)
        { EndManipulation(Self, InState); }

        auto Began = false;
        if (HasBeginManipulation)
        { Began = BeginManipulation(Self, InState, BeginManipulationRequest); }

        if (InState.Manipulation.IsActive)
        { ApplyNudges(Self, InState, NudgeRequests); }

        if (HasEngage && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnEngaged.Broadcast(Self); }

        if (Changed && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnActiveChanged.Broadcast(Self, NewActive); }

        if (Ended && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, false); }

        if (Ended && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(Self, 0.0f); }

        if (Began && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(Self, true); }
    }

    // Lets go before the threshold: the handle settles back to the current target pose from wherever it is.
    private void EndManipulation(FCk_Handle_Control& InControl, FMars_Fragment_Control& InState)
    {
        InState.Manipulation = FMars_Control_Manipulation();
        InControl.Request_TryRemove(FMars_Tag_Control_Manipulating);

        auto Mover = InState.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_Settle(); }
    }

    // Returns false when the control is not ManuallyCompleted (ensures). The grip starts where the handle stands, and
    // the scrub stops an in-flight engage tween so the hand owns the handle.
    private bool BeginManipulation(
        FCk_Handle_Control& InControl,
        FMars_Fragment_Control& InState,
        const FMars_Request_Control_BeginManipulation& InRequest)
    {
        const auto IsManuallyCompleted =
            InControl.Get_CompletionPolicy() == ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        if (ck::EnsureIfNot(IsManuallyCompleted, f"[Control] [{InControl.ToString()}] is not ManuallyCompleted; BeginManipulation ignored"))
        { return false; }

        auto Mover = InState.Mover;
        const auto HasMover = ck::IsValid(Mover);

        auto Manipulation = FMars_Control_Manipulation();
        Manipulation.IsActive = true;
        Manipulation.Interaction = InRequest.Interaction;
        Manipulation.Manipulator = InRequest.Manipulator;
        Manipulation.Alpha = HasMover ? Mover.Get_Alpha() : (InState.IsActive ? 1.0f : 0.0f);
        Manipulation.Pull = Manipulation.Alpha;
        InState.Manipulation = Manipulation;

        if (InControl.Has_Fragment(FMars_Tag_Control_Manipulating) == false)
        { InControl.Add_Fragment(FMars_Tag_Control_Manipulating()); }

        if (HasMover)
        { Mover.Request_Scrub(FMars_Request_Mover_Scrub(Manipulation.Alpha)); }

        return true;
    }

    private void ApplyNudges(
        FCk_Handle_Control& InControl,
        FMars_Fragment_Control& InState,
        const TArray<FMars_Request_Control_Nudge>& InNudges)
    {
        if (InNudges.IsEmpty())
        { return; }

        auto PullDegrees = 0.0f;
        for (const auto& Nudge : InNudges)
        { PullDegrees += Nudge.PullDegrees; }

        const auto AlphaPerDegree = InControl.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.AlphaPerDegree;
        InState.Manipulation.Pull = Math::Clamp(InState.Manipulation.Pull + PullDegrees * AlphaPerDegree, 0.0f, 1.0f);
    }

    private void ArmReleaseTimer(FCk_Handle_Control& InControl, FMars_Fragment_Control& InState, float32 InActiveSeconds)
    {
        DestroyReleaseTimer(InState);

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InActiveSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto ControlEntity = FCk_Handle(InControl);
        auto Timer = utils_timer::Add(ControlEntity, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnReleaseTimerDone")); }
        InState.ReleaseTimer = Timer;
    }

    private void DestroyReleaseTimer(FMars_Fragment_Control& InState)
    {
        if (ck::IsValid(InState.ReleaseTimer))
        { utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(InState.ReleaseTimer)); }

        InState.ReleaseTimer = FCk_Handle_Timer();
    }

    UFUNCTION()
    private void OnReleaseTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        auto Control = Owner.As_Control(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Control))
        { return; }

        // A timer replaced by a re-engage can still finish in the frame it was destroyed.
        const auto& State = Control.Get_Fragment(FMars_Fragment_Control);
        if ((FCk_Handle(State.ReleaseTimer) == FCk_Handle(InTimer)) == false)
        { return; }

        Control.Request_SetActive(false);
    }
}
