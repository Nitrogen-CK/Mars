class UMars_Processor_MechanismSource_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_MechanismSource_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_MechanismSource);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_MechanismSource_Requests& InRequests,
                       FMars_Fragment_MechanismSource& InSourceComp)
    {
        auto Self = InHandle.As_MechanismSource();

        const auto Asserted = InRequests.SetAsserted.Asserted;

        // Swap-and-pop - InRequests is dead past this line; a request enqueued by a listener survives to next pass.
        Self.Request_TryRemove(FMars_Fragment_MechanismSource_Requests);

        if (InSourceComp.IsAsserted == Asserted)
        { return; }

        InSourceComp.IsAsserted = Asserted;

        if (Self.Has_Fragment(FMars_Fragment_MechanismSource_Signals))
        { Self.Get_Fragment(FMars_Fragment_MechanismSource_Signals).OnAssertedChanged.Broadcast(Self, Asserted); }
    }
}
