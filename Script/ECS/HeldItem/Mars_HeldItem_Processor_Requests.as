// Records the requested start poses of the next held visual: UMars_Processor_HeldItem_Sync spawns it, and consumes them,
// when the held item changes.
class UMars_Processor_HeldItem_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_HeldItem_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HeldItem);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_HeldItem_Requests& InRequests,
                       FMars_Fragment_HeldItem& InState)
    {
        auto Self = InHandle.As_HeldItem();

        const auto ClearNextSpawnFrom = InRequests.ClearNextSpawnFromRequests.Num() > 0;
        TArray<FMars_Request_HeldItem_SetNextSpawnFrom> SetNextSpawnFromRequests = InRequests.SetNextSpawnFromRequests;
        TArray<FMars_Request_HeldItem_SetNextArrival> SetNextArrivalRequests = InRequests.SetNextArrivalRequests;

        // InRequests is invalid past this line.
        Self.Request_TryRemove(FMars_Fragment_HeldItem_Requests);

        if (ClearNextSpawnFrom)
        { InState.NextSpawnFrom.Reset(); }

        if (SetNextSpawnFromRequests.Num() > 0)
        { InState.NextSpawnFrom = TOptional<FTransform>(SetNextSpawnFromRequests.Last().WorldTransform); }

        if (SetNextArrivalRequests.Num() > 0)
        {
            const auto& Request = SetNextArrivalRequests.Last();
            InState.NextArrival = TOptional<FMars_WorldItem_PendingArrival>(
                FMars_WorldItem_PendingArrival(Request.Item, Request.World, System::GetGameTimeInSeconds()));
        }
    }
}
