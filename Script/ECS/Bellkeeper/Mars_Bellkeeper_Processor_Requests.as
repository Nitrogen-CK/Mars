// The only writer of the bellkeeper's state. Ended vent pulses deassert first; then one commit per drain, judged against
// the dials as they stand:
// - solved already: ignored;
// - every dial on its answer: solved, dials locked, source asserted, the remaining rewards spawned, OnSolved;
// - otherwise: one more failure, the vent source asserted for VentPulseSeconds (a live pulse restarts), OnCommitFailed.
// The dials keep their positions after a wrong commit, and the verdict never names the wrong dial.
class UMars_Processor_Bellkeeper_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Bellkeeper_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Bellkeeper);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Bellkeeper_Requests& InRequests)
    {
        auto Self = InHandle.As_Bellkeeper();

        const auto EndVentRequests = InRequests.EndVentRequests;
        const auto HasCommit = InRequests.CommitRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Bellkeeper_Requests);

        for (const auto& EndVentRequest : EndVentRequests)
        {
            auto& State = Self.Get_Fragment(FMars_Fragment_Bellkeeper);
            if (ck::IsValid(EndVentRequest.Timer) && State.VentTimer == EndVentRequest.Timer)
            { EndVent(Self, State); }
        }

        if (HasCommit == false || Self.Get_IsSolved())
        { return; }

        if (Get_IsAnswered(Self))
        { Solve(Self); }
        else
        { Fail(Self); }
    }

    private bool Get_IsAnswered(const FCk_Handle_Bellkeeper& InBellkeeper) const
    {
        const auto& Params = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params);
        for (int32 Index = 0; Index < Params.Dials.Num(); ++Index)
        {
            const auto& Dial = Params.Dials[Index];
            if (ck::EnsureIfNot(ck::IsValid(Dial), f"[Bellkeeper] [{InBellkeeper.ToString()}] lost Dials[{Index}]; the lock cannot open"))
            { return false; }

            if (Dial.Get_Index() != Params.Answer[Index])
            { return false; }
        }

        return true;
    }

    private void Solve(FCk_Handle_Bellkeeper& InBellkeeper)
    {
        auto Params = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params);
        const auto FirstPaid = Params.Rewards.Num() - InBellkeeper.Get_RemainingRewards();

        auto& State = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper);
        State.Solved = true;
        EndVent(InBellkeeper, State);

        for (auto& Dial : Params.Dials)
        { Dial.Request_SetLocked(FMars_Request_Dial_SetLocked(true)); }

        auto Source = InBellkeeper.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        { Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(EMars_MechanismSource_Output::Asserted)); }

        // Spawned once: Solved is set above, so no later commit reaches here. An unresolvable definition ensures in
        // Request_SpawnWorld and leaves an invalid handle rather than a retry.
        auto Owner = InBellkeeper.H();
        for (int32 Index = FirstPaid; Index < Params.Rewards.Num(); ++Index)
        {
            const auto& Reward = Params.Rewards[Index];
            const auto Spawned = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(Reward.Definition, Reward.Transform));
            InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper).RewardHandles.Add(Spawned);
        }

        if (InBellkeeper.Has_Fragment(FMars_Fragment_Bellkeeper_Signals))
        { InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnSolved.Broadcast(InBellkeeper); }
    }

    private void Fail(FCk_Handle_Bellkeeper& InBellkeeper)
    {
        const auto& Params = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params);
        auto VentSource = Params.VentSource;
        const auto PulseSeconds = Params.VentPulseSeconds;

        auto& State = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper);
        State.FailedCommits += 1;

        if (ck::IsValid(VentSource))
        {
            DestroyVentTimer(State);
            State.VentTimer = ArmVentTimer(InBellkeeper, PulseSeconds);
            VentSource.Request_SetOutput(utils_mechanism_source::Make_SetOutput(EMars_MechanismSource_Output::Asserted));
        }

        const auto Remaining = InBellkeeper.Get_RemainingRewards();
        if (InBellkeeper.Has_Fragment(FMars_Fragment_Bellkeeper_Signals))
        { InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnCommitFailed.Broadcast(InBellkeeper, Remaining); }
    }

    private void EndVent(FCk_Handle_Bellkeeper& InBellkeeper, FMars_Fragment_Bellkeeper& InState)
    {
        if (ck::Is_NOT_Valid(InState.VentTimer))
        { return; }

        DestroyVentTimer(InState);

        auto VentSource = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentSource;
        if (ck::IsValid(VentSource))
        { VentSource.Request_SetOutput(utils_mechanism_source::Make_SetOutput(EMars_MechanismSource_Output::Deasserted)); }
    }

    private void DestroyVentTimer(FMars_Fragment_Bellkeeper& InState)
    {
        if (ck::IsValid(InState.VentTimer))
        { utils_entity_lifetime::Request_DestroyEntity(InState.VentTimer.H()); }

        InState.VentTimer = FCk_Handle_Timer();
    }

    private FCk_Handle_Timer ArmVentTimer(FCk_Handle_Bellkeeper& InBellkeeper, float32 InSeconds)
    {
        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InBellkeeper.H(), TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnVentTimerDone")); }

        return Timer;
    }

    UFUNCTION()
    private void OnVentTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The owner is gone only while the bellkeeper is being torn down.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        // A pulse restarted by a newer wrong commit can still finish in the frame it was destroyed; the drain drops it.
        auto Bellkeeper = Owner.As_Bellkeeper();
        Bellkeeper.Request_EndVent(FMars_Request_Bellkeeper_EndVent(InTimer));
    }
}
