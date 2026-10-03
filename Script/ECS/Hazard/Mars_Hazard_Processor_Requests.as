class UMars_Processor_Hazard_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Hazard_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hazard);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Hazard_Requests& InRequests,
                       FMars_Fragment_Hazard& InState)
    {
        auto Hazard = InHandle.As_Hazard();

        // Absolute requests: the last one stands.
        const auto Arming = InRequests.SetArmedRequests.Last().Arming;

        // InRequests is invalid past this line; a request enqueued by a listener survives to the next pass.
        Hazard.Request_TryRemove(FMars_Fragment_Hazard_Requests);

        if (InState.Arming == Arming)
        { return; }

        InState.Arming = Arming;

        // Hitting what is already inside on arming is the setup processor's reaction to this signal.
        if (Hazard.Has_Fragment(FMars_Fragment_Hazard_Signals))
        { Hazard.Get_Fragment(FMars_Fragment_Hazard_Signals).OnArmedChanged.Broadcast(Hazard, Arming); }
    }
}
