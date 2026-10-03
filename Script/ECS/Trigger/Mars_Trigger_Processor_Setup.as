// Forwards the trigger entity's own probe overlaps to OnEntityEntered / OnEntityExited.
class UMars_Processor_Trigger_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Trigger_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Trigger);
        Query.Require(FMars_Tag_Trigger_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Probe = InHandle.As_Probe();
        utils_probe::BindTo_OnBeginOverlap(Probe, FCk_Delegate_Probe_OnBeginOverlap(this, n"OnProbeBeginOverlap"));
        utils_probe::BindTo_OnEndOverlap(Probe, FCk_Delegate_Probe_OnEndOverlap(this, n"OnProbeEndOverlap"));

        InHandle.Request_TryRemove(FMars_Tag_Trigger_NeedsSetup);
    }

    UFUNCTION()
    private void OnProbeBeginOverlap(FCk_Handle_Probe InProbe, FCk_Probe_Payload_OnBeginOverlap InPayload)
    {
        auto Trigger = InProbe.As_Trigger();

        auto Entity = InPayload.Get_OtherEntity();
        auto& State = Trigger.Get_Fragment(FMars_Fragment_Trigger);
        if (State.EntitiesInside.Contains(Entity))
        { return; }

        PruneInvalid(State);
        State.EntitiesInside.Add(Entity);

        if (Trigger.Has_Fragment(FMars_Fragment_Trigger_Signals))
        { Trigger.Get_Fragment(FMars_Fragment_Trigger_Signals).OnEntityEntered.Broadcast(Trigger, Entity); }
    }

    UFUNCTION()
    private void OnProbeEndOverlap(FCk_Handle_Probe InProbe, FCk_Probe_Payload_OnEndOverlap InPayload)
    {
        auto Trigger = InProbe.As_Trigger();

        // Matched before pruning: an entity being destroyed still reports its exit with a now-invalid handle.
        auto Entity = InPayload.Get_OtherEntity();
        auto& State = Trigger.Get_Fragment(FMars_Fragment_Trigger);
        if (State.EntitiesInside.Contains(Entity) == false)
        { return; }

        State.EntitiesInside.Remove(Entity);
        PruneInvalid(State);

        if (Trigger.Has_Fragment(FMars_Fragment_Trigger_Signals))
        { Trigger.Get_Fragment(FMars_Fragment_Trigger_Signals).OnEntityExited.Broadcast(Trigger, Entity); }
    }

    private void PruneInvalid(FMars_Fragment_Trigger& InState)
    {
        for (int32 Index = InState.EntitiesInside.Num() - 1; Index >= 0; --Index)
        {
            if (ck::Is_NOT_Valid(InState.EntitiesInside[Index]))
            { InState.EntitiesInside.RemoveAt(Index); }
        }
    }
}
