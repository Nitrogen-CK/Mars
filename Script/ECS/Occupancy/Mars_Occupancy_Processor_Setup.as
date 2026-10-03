// Recounts on every trigger enter/exit, drives IsActive (with the release delay) and the optional mover, and is the
// link: an occupancy that also has a MechanismSource asserts it while active.
class UMars_Processor_Occupancy_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Occupancy_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Occupancy);
        Query.Require(FMars_Tag_Occupancy_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Occupancy = InHandle.As_Occupancy();

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        { Occupancy.BindTo_OnActiveChanged(FMars_Delegate_Occupancy_OnActiveChanged(this, n"OnOccupancyActiveChanged")); }

        // Add links the trigger, so the link is there whenever the trigger is still alive.
        auto Trigger = Occupancy.Get_Trigger();
        if (ck::IsValid(Trigger))
        {
            auto& Link = Trigger.Get_Fragment(FMars_Fragment_Occupancy_TriggerLink);
            if (Link.IsBound == false)
            {
                Link.IsBound = true;
                Trigger.BindTo_OnEntityEntered(FMars_Delegate_Trigger_OnEntityEntered(this, n"OnTriggerEntityEntered"));
                Trigger.BindTo_OnEntityExited(FMars_Delegate_Trigger_OnEntityExited(this, n"OnTriggerEntityExited"));
            }
        }

        Recount(Occupancy);

        if (ck::IsValid(Source))
        { Source.Request_SetOutput(Make_SetOutput(Occupancy.Get_IsActive())); }

        Occupancy.Request_TryRemove(FMars_Tag_Occupancy_NeedsSetup);
    }

    private FMars_Request_MechanismSource_SetOutput Make_SetOutput(bool InActive) const
    {
        return FMars_Request_MechanismSource_SetOutput(InActive ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted);
    }

    UFUNCTION()
    private void OnTriggerEntityEntered(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        RecountLinked(InTrigger);
    }

    UFUNCTION()
    private void OnTriggerEntityExited(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        RecountLinked(InTrigger);
    }

    UFUNCTION()
    private void OnOccupancyActiveChanged(FCk_Handle_Occupancy InOccupancy, EMars_Occupancy_Activation InActivation)
    {
        auto Source = InOccupancy.As_MechanismSource();
        Source.Request_SetOutput(Make_SetOutput(InActivation == EMars_Occupancy_Activation::Active));
    }

    UFUNCTION()
    private void OnReleaseTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The owner is gone only while the occupancy is being torn down.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Occupancy = Owner.As_Occupancy();

        // A timer cancelled by a re-entry can still finish in the frame it was destroyed.
        if (Occupancy.Get_Fragment(FMars_Fragment_Occupancy).ReleaseTimer != InTimer)
        { return; }

        DestroyReleaseTimer(Occupancy);

        if (Occupancy.Get_Count() >= Occupancy.Get_RequiredCount())
        { return; }

        SetActive(Occupancy, false);
    }

    private void RecountLinked(FCk_Handle_Trigger InTrigger)
    {
        // Copied: a recount broadcasts, and a listener may change the link.
        auto Occupancies = InTrigger.Get_Fragment(FMars_Fragment_Occupancy_TriggerLink).Occupancies;
        for (auto LinkedOccupancy : Occupancies)
        {
            auto Occupancy = LinkedOccupancy;
            if (ck::IsValid(Occupancy))
            { Recount(Occupancy); }
        }
    }

    private void Recount(FCk_Handle_Occupancy& InOccupancy)
    {
        const auto& Params = InOccupancy.Get_Fragment(FMars_Fragment_Occupancy_Params);
        const auto RequiredCount = Params.RequiredCount;
        const auto ReleaseDelaySeconds = Params.ReleaseDelaySeconds;

        auto& State = InOccupancy.Get_Fragment(FMars_Fragment_Occupancy);
        const auto NewCount = ck::IsValid(State.Trigger) ? State.Trigger.Get_EntityCount() : 0;
        const auto CountChanged = NewCount != State.Count;
        State.Count = NewCount;

        if (NewCount >= RequiredCount)
        {
            DestroyReleaseTimer(InOccupancy);
            SetActive(InOccupancy, true);
        }
        else if (State.IsActive == false)
        {
            DestroyReleaseTimer(InOccupancy);
        }
        else if (ReleaseDelaySeconds <= 0.0f)
        {
            SetActive(InOccupancy, false);
        }
        // Only the first drop below RequiredCount starts the countdown; later exits do not extend it.
        else if (ck::Is_NOT_Valid(State.ReleaseTimer))
        {
            ArmReleaseTimer(InOccupancy, ReleaseDelaySeconds);
        }

        if (CountChanged && InOccupancy.Has_Fragment(FMars_Fragment_Occupancy_Signals))
        { InOccupancy.Get_Fragment(FMars_Fragment_Occupancy_Signals).OnCountChanged.Broadcast(InOccupancy, NewCount); }
    }

    private void SetActive(FCk_Handle_Occupancy& InOccupancy, bool InActive)
    {
        auto& State = InOccupancy.Get_Fragment(FMars_Fragment_Occupancy);
        if (State.IsActive == InActive)
        { return; }

        State.IsActive = InActive;

        auto Mover = State.Mover;
        if (ck::IsValid(Mover))
        { Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(InActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start)); }

        if (InOccupancy.Has_Fragment(FMars_Fragment_Occupancy_Signals))
        {
            const auto Activation = InActive ? EMars_Occupancy_Activation::Active : EMars_Occupancy_Activation::Inactive;
            InOccupancy.Get_Fragment(FMars_Fragment_Occupancy_Signals).OnActiveChanged.Broadcast(InOccupancy, Activation);
        }
    }

    private void ArmReleaseTimer(FCk_Handle_Occupancy& InOccupancy, float32 InDelaySeconds)
    {
        DestroyReleaseTimer(InOccupancy);

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InDelaySeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InOccupancy.H(), TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnReleaseTimerDone")); }

        InOccupancy.Get_Fragment(FMars_Fragment_Occupancy).ReleaseTimer = Timer;
    }

    private void DestroyReleaseTimer(FCk_Handle_Occupancy& InOccupancy)
    {
        auto& State = InOccupancy.Get_Fragment(FMars_Fragment_Occupancy);
        if (ck::IsValid(State.ReleaseTimer))
        { utils_entity_lifetime::Request_DestroyEntity(State.ReleaseTimer.H()); }

        State.ReleaseTimer = FCk_Handle_Timer();
    }
}
