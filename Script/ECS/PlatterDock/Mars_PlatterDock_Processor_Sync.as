// Polls each dock's item against the last pass (the cargo slot's Sync shape). A change records the platter's world item and
// kernel, then broadcasts OnUndocked for the platter that left and OnDocked for the one that arrived. It never moves the
// platter: the Dock's Carry and the taker's Hold do. It is also the dock's teardown listener, bound at its first dock: a
// dock torn down under a docked platter ends that platter, so no platter rides (or still lerps onto) a dead node.
class UMars_Processor_PlatterDock_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PlatterDock);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_PlatterDock& InState)
    {
        auto Now = InState.Inventory.Get_SoleItem();
        if (Now == InState.LastSeen)
        { return; }

        const auto Previous = InState.Platter;

        const auto Docked = utils_platter_dock::TryGet_PlatterOf(Now);

        InState.LastSeen = Now;
        InState.WorldItem = ck::IsValid(Now) ? Now.Get_PersistentWorldItem() : FCk_Handle_WorldItem();
        InState.Platter = Docked;

        // InState is not read past this line: a listener may add a fragment to the dock (a request).
        auto Self = InHandle.As_PlatterDock();
        if (ck::IsValid(Previous))
        {
            ck::Trace(f"[PlatterDock] [{Self.ToString()}] undocked [{Previous.ToString()}]");
            Broadcast_Undocked(Self, Previous);
        }

        if (ck::IsValid(Docked))
        {
            ck::Trace(f"[PlatterDock] [{Self.ToString()}] docked [{Docked.ToString()}]");
            Watch_Teardown(InHandle);
            Broadcast_Docked(Self, Docked);
        }
    }

    // Unbinding first keeps the watch single across docks.
    private void Watch_Teardown(FCk_Handle& InDock)
    {
        InDock.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnDockBeginDestroy"));
        InDock.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnDockBeginDestroy"));
    }

    // The item lives in the dock's inventory and dies with it: a dead dock ends its platter (the Platter's own teardown
    // ends the pieces on it); re-homing the item is a WorldItem change. A release would also turn the platter's body
    // Dynamic against the station's furniture while its static bodies are torn down. A dock emptied since its last dock
    // has nothing to end.
    UFUNCTION()
    private void OnDockBeginDestroy(FCk_Handle InDock)
    {
        auto DockEntity = InDock;
        if (DockEntity.Has_Fragment(FMars_Fragment_PlatterDock) == false)
        { return; }

        const auto State = DockEntity.Get_Fragment(FMars_Fragment_PlatterDock);
        const auto Item = State.Inventory.Get_SoleItem();
        if (ck::Is_NOT_Valid(Item))
        { return; }

        const auto WorldItem = Item.Get_PersistentWorldItem();
        if (ck::Is_NOT_Valid(WorldItem) || utils_entity_lifetime::Get_IsPendingDestroy(WorldItem, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(WorldItem);
        ck::Trace(f"[PlatterDock] [{DockEntity.ToString()}] torn down: ends its platter [{WorldItem.ToString()}]");
    }

    private void Broadcast_Undocked(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Platter& InPlatter)
    {
        if (InDock.Has_Fragment(FMars_Fragment_PlatterDock_Signals))
        { InDock.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnUndocked.Broadcast(InDock, InPlatter); }
    }

    private void Broadcast_Docked(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Platter& InPlatter)
    {
        if (InDock.Has_Fragment(FMars_Fragment_PlatterDock_Signals))
        { InDock.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnDocked.Broadcast(InDock, InPlatter); }
    }
}
