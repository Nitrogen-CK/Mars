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

        if (Self.Has_Fragment(FMars_Fragment_Control_Signals) == false)
        { return; }

        if (HasEngage)
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnEngaged.Broadcast(Self); }

        if (Changed && Self.Has_Fragment(FMars_Fragment_Control_Signals))
        { Self.Get_Fragment(FMars_Fragment_Control_Signals).OnActiveChanged.Broadcast(Self, NewActive); }
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
