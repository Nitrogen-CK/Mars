// Applies Select, Deselect and Cycle requests in arrival order. While the overflow slot holds an item, any selection
// that would leave it is parked instead of applied; the sync pass applies it once the overflow item is gone.
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

        TArray<FMars_Hotbar_SelectionChangeRequest> SelectionChangeRequests = InRequests.SelectionChangeRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Hotbar_Requests);

        for (const auto& Request : SelectionChangeRequests)
        {
            if (Request.Change == EMars_Hotbar_SelectionChange::Select)
            {
                if (ck::EnsureIfNot(Request.Index.IsSet(), f"[Hotbar] [{Self.ToString()}] got a Select request with no index"))
                { continue; }

                HandleSelectRequest(Self, InState, Request.Index.GetValue());
            }
            else if (Request.Change == EMars_Hotbar_SelectionChange::Deselect)
            { HandleDeselectRequest(Self, InState); }
            else if (Request.Change == EMars_Hotbar_SelectionChange::CycleNext)
            { HandleCycleRequest(Self, InState, EMars_Hotbar_CycleDirection::Next); }
            else
            { HandleCycleRequest(Self, InState, EMars_Hotbar_CycleDirection::Previous); }
        }
    }

    private void HandleSelectRequest(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, int32 InIndex)
    {
        const auto OverflowIndex = InHotbar.Get_OverflowIndex();
        const auto LastIndex = InHotbar.Get_LastIndex();
        const auto IndexIsInRange = InIndex >= 0 && InIndex <= LastIndex;
        if (ck::EnsureIfNot(IndexIsInRange, f"[Hotbar] Select index [{InIndex}] is outside [0, {LastIndex}] (the last index is the backpack slot when present, else the overflow slot)"))
        { return; }

        const auto Target = TOptional<int32>(InIndex);
        if (Target == InState.SelectedIndex)
        {
            HandleDeselectRequest(InHotbar, InState);
            return;
        }

        if (InIndex != OverflowIndex && TryPark(InHotbar, InState, Target))
        { return; }

        utils_hotbar::Apply_Selection(InHotbar, InState, Target);
    }

    private void HandleDeselectRequest(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState)
    {
        const auto NoSelection = TOptional<int32>();
        if (TryPark(InHotbar, InState, NoSelection))
        { return; }

        utils_hotbar::Apply_Selection(InHotbar, InState, NoSelection);
    }

    private void HandleCycleRequest(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, EMars_Hotbar_CycleDirection InDirection)
    {
        const auto BagSlotCount = InHotbar.Get_BagSlotCount();
        const auto Step = InDirection == EMars_Hotbar_CycleDirection::Next ? 1 : -1;
        const auto CurrentIsBagSlot = InState.SelectedIndex.IsSet() && InState.SelectedIndex.GetValue() < BagSlotCount;

        int32 Target = 0;
        if (CurrentIsBagSlot)
        { Target = (((InState.SelectedIndex.GetValue() + Step) % BagSlotCount) + BagSlotCount) % BagSlotCount; }
        else if (InDirection == EMars_Hotbar_CycleDirection::Previous)
        { Target = BagSlotCount - 1; }

        HandleSelectRequest(InHotbar, InState, Target);
    }

    // Leaving an occupied overflow slot drops its item first: park the target and ask for the eject once per park.
    private bool TryPark(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, TOptional<int32> InTarget)
    {
        const auto OverflowItem = InHotbar.Get_ItemAt(InHotbar.Get_OverflowIndex());
        if (ck::Is_NOT_Valid(OverflowItem))
        { return false; }

        const auto AlreadyParked = InState.ParkedSelection.IsSet();
        InState.ParkedSelection = TOptional<FMars_Hotbar_ParkedSelection>(FMars_Hotbar_ParkedSelection(InTarget));

        if (AlreadyParked)
        { return true; }

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals))
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnOverflowEjectRequested.Broadcast(InHotbar, OverflowItem); }

        return true;
    }
}
