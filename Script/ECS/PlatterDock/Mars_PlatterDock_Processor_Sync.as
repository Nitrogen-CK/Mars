// Polls each dock's item against the last pass (the cargo slot's Sync shape), on every machine: a client's dock reads its
// replicated inventory. A change broadcasts OnUndocked for the platter that left, then records the arrived item's platter
// and world item and broadcasts OnDocked. An item whose platter this machine cannot resolve yet (its item not linked to its
// world item) is looked up again each pass while it stays the dock's item; the pass that resolves it records it and
// broadcasts OnDocked as an arrival would. A docked platter's world item is watched through its own OnMountSettled: when it
// settles Carried by this dock, the dock broadcasts OnArrived (once per dock; Get_HasArrived reads the same fact). A
// station takes from a platter only once it has landed, never while it is still travelling from the hand. On the
// authority, a docked platter that has not settled ArriveSeconds + k_SettleGraceSeconds after docking ensures once. The
// dock never moves the platter: its world item mounts from where its item lives.
class UMars_Processor_PlatterDock_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_PlatterDock_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_Mount");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PlatterDock);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_PlatterDock& InState)
    {
        auto Now = InState.Inventory.Get_SoleItem();
        if (Now == InState.LastSeen)
        {
            if (ck::IsValid(Now) && ck::Is_NOT_Valid(InState.Platter))
            {
                Try_RecordDocked(InHandle, Now);
                return;
            }

            if (utils_net::Get_HasAuthority(InHandle))
            { Watch_Settle(InHandle, InState, float32(InDeltaT.Get_Seconds())); }

            return;
        }

        const auto Previous = InState.Platter;
        auto PreviousWorldItem = InState.WorldItem;

        InState.LastSeen = Now;
        InState.WorldItem = FCk_Handle_WorldItem();
        InState.Platter = FCk_Handle_Platter();
        InState.SettleWatchSeconds.Reset();

        // InState is not read past this line: a listener may add a fragment to the dock.
        auto Self = InHandle.As_PlatterDock();
        if (ck::IsValid(PreviousWorldItem))
        { Stop_Watching(PreviousWorldItem); }

        if (ck::IsValid(Previous))
        { Broadcast_Undocked(Self, Previous); }

        if (ck::IsValid(Now))
        { Try_RecordDocked(InHandle, Now); }
    }

    // Records InItem's platter and world item once this machine resolves them, then broadcasts OnDocked, and OnArrived at
    // once when the mount committed without travel. Nothing while the platter cannot be resolved.
    private void Try_RecordDocked(FCk_Handle& InHandle, const FCk_Handle_Item& InItem)
    {
        const auto Docked = utils_platter_dock::TryGet_PlatterOf(InItem);
        if (ck::Is_NOT_Valid(Docked))
        { return; }

        auto& State = InHandle.Get_Fragment(FMars_Fragment_PlatterDock);
        State.WorldItem = InItem.Get_PersistentWorldItem();
        State.Platter = Docked;
        State.SettleWatchSeconds = TOptional<float32>(0.0f);
        auto DockedWorldItem = State.WorldItem;

        // State is not read past this line: a listener may add a fragment to the dock.
        auto Self = InHandle.As_PlatterDock();
        DockedWorldItem.UnbindFrom_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnDockedMountSettled"));
        DockedWorldItem.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnDockedMountSettled"));
        Broadcast_Docked(Self, Docked);

        // A mount committed without travel settled before this bind.
        if (Self.Get_HasArrived())
        { Report_Arrived(Self); }
    }

    // The watchdog: a docked platter that has not settled on the dock past its arrival and the grace ensures once.
    private void Watch_Settle(FCk_Handle& InDock, FMars_Fragment_PlatterDock& InState, float32 InDeltaSeconds)
    {
        if (InState.SettleWatchSeconds.IsSet() == false)
        { return; }

        const auto Dock = InDock.As_PlatterDock();
        if (Dock.Get_HasArrived())
        {
            InState.SettleWatchSeconds.Reset();
            return;
        }

        const auto Waited = InState.SettleWatchSeconds.GetValue() + InDeltaSeconds;
        InState.SettleWatchSeconds = TOptional<float32>(Waited);

        const auto WorldItem = InState.WorldItem;
        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(WorldItem);
        const auto ArriveSeconds = ck::IsValid(Presentation) ? Presentation.Mounting.ArriveSeconds : 0.0f;
        if (Waited <= ArriveSeconds + constants_platter_dock::k_SettleGraceSeconds)
        { return; }

        InState.SettleWatchSeconds.Reset();
        ck::EnsureIfNot(false,
            f"[PlatterDock] [{Dock.ToString()}] docked [{InState.Platter.ToString()}] {Waited :.2} s ago and it has not settled on the dock (mount [{WorldItem.Get_Mount() :n}], carrier [{WorldItem.Get_Carrier().ToString()}], target [{WorldItem.Get_TargetMount() :n}])");
    }

    // The platter that left stops being watched, unless another dock holds it now (that dock watches it).
    private void Stop_Watching(FCk_Handle_WorldItem& InWorldItem)
    {
        const auto Item = InWorldItem.Get_Item();
        if (ck::IsValid(Item))
        {
            FCk_Handle Inventory = Item.Get_ParentInventory();
            if (ck::IsValid(Inventory) && utils_entity_lifetime::Get_LifetimeOwner(Inventory).Is_PlatterDock())
            { return; }
        }

        InWorldItem.UnbindFrom_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnDockedMountSettled"));
    }

    // Only a settle on the dock that holds the platter now is an arrival.
    UFUNCTION()
    private void OnDockedMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        auto Dock = InCarrier.As_PlatterDock(ECk_SanityCheck::UnChecked);
        if (InMount != EMars_WorldItem_Mount::Carried || ck::Is_NOT_Valid(Dock) || Dock.Get_WorldItem() != InWorldItem)
        { return; }

        if (Dock.Get_HasArrived())
        { Report_Arrived(Dock); }
    }

    private void Report_Arrived(FCk_Handle_PlatterDock& InDock)
    {
        auto& State = InDock.Get_Fragment(FMars_Fragment_PlatterDock);
        State.SettleWatchSeconds.Reset();
        const auto Platter = State.Platter;

        // State is not read past this line: a listener may add a fragment to the dock (a request).
        if (InDock.Has_Fragment(FMars_Fragment_PlatterDock_Signals))
        { InDock.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnArrived.Broadcast(InDock, Platter); }
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
