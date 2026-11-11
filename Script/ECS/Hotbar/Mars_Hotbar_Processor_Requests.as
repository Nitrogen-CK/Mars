// Applies Select, Deselect, Cycle and Set requests in arrival order, on the authority only: each resolves to an absolute
// target against the selection as it stands (utils_hotbar::Resolve_SelectionChange: a Select of the selected slot
// deselects), then the target applies. While the overflow slot holds an item, any target that would leave it is parked
// instead of applied (the eject serial advances once per park); the sync pass applies it once the overflow item is gone.
// A client's selection arrives as a Set through Cue.Mars.Hotbar.Select; a request queued on a client is dropped.
class UMars_Processor_Hotbar_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_HeldItem_HandleRequests");
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

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : SelectionChangeRequests)
        {
            if (Request.Change == EMars_Hotbar_SelectionChange::Select)
            {
                if (ck::EnsureIfNot(Request.Index.IsSet(), f"[Hotbar] [{Self.ToString()}] got a Select request with no index"))
                { continue; }
            }

            HandleSetRequest(Self, InState, utils_hotbar::Resolve_SelectionChange(Self, Request));
        }
    }

    private void HandleSetRequest(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, TOptional<int32> InTarget)
    {
        if (InTarget.IsSet())
        {
            const auto Index = InTarget.GetValue();
            const auto LastIndex = InHotbar.Get_LastIndex();
            const auto IndexIsInRange = Index >= 0 && Index <= LastIndex;
            if (ck::EnsureIfNot(IndexIsInRange, f"[Hotbar] Selection index [{Index}] is outside [0, {LastIndex}] (the last index is the backpack slot when present, else the overflow slot)"))
            { return; }

            if (Index == InHotbar.Get_OverflowIndex())
            {
                utils_hotbar::Apply_Selection(InHotbar, InState, InTarget);
                return;
            }
        }

        if (TryPark(InHotbar, InState, InTarget))
        { return; }

        utils_hotbar::Apply_Selection(InHotbar, InState, InTarget);
    }

    // Leaving an occupied overflow slot drops its item first: park the target and ask for the eject once per park.
    private bool TryPark(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, TOptional<int32> InTarget)
    {
        const auto OverflowItem = InHotbar.Get_ItemAt(InHotbar.Get_OverflowIndex());
        if (ck::Is_NOT_Valid(OverflowItem))
        { return false; }

        const auto AlreadyParked = InState.Park == EMars_Hotbar_Park::Parked;
        InState.Park = EMars_Hotbar_Park::Parked;
        InState.ParkedIndex = InTarget;
        if (AlreadyParked == false)
        { InState.EjectSerial += 1; }

        InHotbar.H().Request_MarkReplicationDirty(FMars_Fragment_Hotbar);

        if (AlreadyParked)
        { return true; }

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals))
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnOverflowEjectRequested.Broadcast(InHotbar, OverflowItem); }

        return true;
    }
}
