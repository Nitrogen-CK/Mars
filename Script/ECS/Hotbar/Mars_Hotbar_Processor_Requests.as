// Drains Select, then Deselect, then Cycle. While the overflow slot holds an item, any selection that would leave it
// is parked instead of applied; the sync pass applies it once the overflow item is gone.
class UMars_Processor_Hotbar_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Hotbar_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hotbar);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Hotbar_Requests& InRequests,
                       FMars_Fragment_Hotbar& InState)
    {
        auto Self = InHandle.As_Hotbar();

        TArray<FMars_Request_Hotbar_Select> SelectRequests = InRequests.SelectRequests;
        TArray<FMars_Request_Hotbar_Deselect> DeselectRequests = InRequests.DeselectRequests;
        TArray<FMars_Request_Hotbar_Cycle> CycleRequests = InRequests.CycleRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Hotbar_Requests);

        for (const auto& Request : SelectRequests)
        { HandleSelectRequest(Self, InState, Request.Index); }

        for (int32 Index = 0; Index < DeselectRequests.Num(); ++Index)
        { HandleDeselectRequest(Self, InState); }

        for (const auto& Request : CycleRequests)
        { HandleCycleRequest(Self, InState, Request.Direction); }
    }

    private void HandleSelectRequest(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, int32 InIndex)
    {
        const auto OverflowIndex = InHotbar.Get_OverflowIndex();
        const auto LastIndex = InHotbar.Get_LastIndex();
        const auto IndexIsInRange = InIndex >= 0 && InIndex <= LastIndex;
        if (ck::EnsureIfNot(IndexIsInRange, f"[Hotbar] Select index [{InIndex}] is outside [0, {LastIndex}] (the last index is the backpack slot when present, else the overflow slot)"))
        { return; }

        if (InIndex == InState.SelectedIndex)
        {
            HandleDeselectRequest(InHotbar, InState);
            return;
        }

        if (InIndex != OverflowIndex && TryPark(InHotbar, InState, InIndex))
        { return; }

        ApplySelection(InHotbar, InState, InIndex);
    }

    private void HandleDeselectRequest(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState)
    {
        if (TryPark(InHotbar, InState, -1))
        { return; }

        ApplySelection(InHotbar, InState, -1);
    }

    private void HandleCycleRequest(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, int32 InDirection)
    {
        const auto BagSlotCount = InHotbar.Get_BagSlotCount();
        const auto CurrentIsBagSlot = InState.SelectedIndex >= 0 && InState.SelectedIndex < BagSlotCount;

        int32 Target = 0;
        if (CurrentIsBagSlot)
        { Target = (((InState.SelectedIndex + InDirection) % BagSlotCount) + BagSlotCount) % BagSlotCount; }
        else if (InDirection < 0)
        { Target = BagSlotCount - 1; }

        HandleSelectRequest(InHotbar, InState, Target);
    }

    // Leaving an occupied overflow slot drops its item first: park the target and ask for the eject once per park.
    private bool TryPark(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, int32 InTargetIndex)
    {
        const auto OverflowItem = InHotbar.Get_ItemAt(InHotbar.Get_OverflowIndex());
        if (ck::Is_NOT_Valid(OverflowItem))
        { return false; }

        const auto AlreadyParked = InState.PendingSelectedIndex != -2;
        InState.PendingSelectedIndex = InTargetIndex;

        if (AlreadyParked)
        { return true; }

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals))
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnOverflowEjectRequested.Broadcast(InHotbar, OverflowItem, InTargetIndex); }

        return true;
    }

    // SelectedIndex is written only here and in the other hotbar processor's copy (UMars_Processor_Hotbar_Sync).
    private void ApplySelection(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, int32 InNewIndex)
    {
        const auto PrevIndex = InState.SelectedIndex;
        if (PrevIndex == InNewIndex)
        { return; }

        InState.SelectedIndex = InNewIndex;

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals))
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSelectionChanged.Broadcast(InHotbar, PrevIndex, InNewIndex); }
    }
}
