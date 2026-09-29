class UMars_Processor_Sequence_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Sequence_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Sequence);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Sequence_Requests& InRequests)
    {
        const auto HasReset = InRequests.ResetRequest.IsSet();

        // Swap-and-pop - InRequests is dead past this line; a request enqueued by a listener survives to next pass.
        InHandle.Request_TryRemove(FMars_Fragment_Sequence_Requests);

        if (HasReset == false)
        { return; }

        auto Sequence = InHandle.As_Sequence();
        utils_sequence::Reset(Sequence);
    }
}

