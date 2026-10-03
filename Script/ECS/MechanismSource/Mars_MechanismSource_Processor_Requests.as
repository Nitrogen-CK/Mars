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

        const auto Output = InRequests.SetOutputRequests.Last().Output;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_MechanismSource_Requests);

        if (InSourceComp.Output == Output)
        { return; }

        InSourceComp.Output = Output;

        if (Self.Has_Fragment(FMars_Fragment_MechanismSource_Signals))
        { Self.Get_Fragment(FMars_Fragment_MechanismSource_Signals).OnAssertedChanged.Broadcast(Self, Output); }
    }
}
