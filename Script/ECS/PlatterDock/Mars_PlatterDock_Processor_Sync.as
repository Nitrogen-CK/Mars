// Polls each dock's item against the last pass (the cargo slot's Sync shape). A change records the platter's world item and
// kernel, then broadcasts OnUndocked for the platter that left and OnDocked for the one that arrived. A docked platter's
// world item is watched through its own OnMountSettled: when it settles Carried by this dock, the dock broadcasts OnArrived
// (once per dock; Get_HasArrived reads the same fact). A station takes from a platter only once it has landed, never while
// it is still travelling from the hand. A docked platter that has not settled ArriveSeconds + k_SettleGraceSeconds after
// docking ensures once. The dock never moves the platter: its world item mounts from where its item lives.
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
            Watch_Settle(InHandle, InState, float32(InDeltaT.Get_Seconds()));
            return;
        }

        const auto Previous = InState.Platter;
        auto PreviousWorldItem = InState.WorldItem;

        const auto Docked = utils_platter_dock::TryGet_PlatterOf(Now);

        InState.LastSeen = Now;
        InState.WorldItem = ck::IsValid(Now) ? Now.Get_PersistentWorldItem() : FCk_Handle_WorldItem();
        InState.Platter = Docked;
        InState.SettleWatchSeconds.Reset();
        if (ck::IsValid(Docked))
        { InState.SettleWatchSeconds = TOptional<float32>(0.0f); }

        auto DockedWorldItem = InState.WorldItem;

        // InState is not read past this line: the reach hint and a listener may add a fragment to the dock.
        Sync_ReachHint(InHandle, Docked, DockedWorldItem);
        auto Self = InHandle.As_PlatterDock();
        if (ck::IsValid(PreviousWorldItem))
        { Stop_Watching(PreviousWorldItem); }

        if (ck::IsValid(Previous))
        { Broadcast_Undocked(Self, Previous); }

        if (ck::IsValid(Docked) == false)
        { return; }

        DockedWorldItem.UnbindFrom_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnDockedMountSettled"));
        DockedWorldItem.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnDockedMountSettled"));
        Broadcast_Docked(Self, Docked);

        // A mount committed without travel settled before this bind.
        if (Self.Get_HasArrived())
        { Report_Arrived(Self); }
    }

    // A docked platter is what a Take reaches for: the dock (the interactable's owner) hints the platter's own fit and
    // handedness, so both gloves take the tray. The platter's root sits on the dock's node, so its fit holds in the dock's
    // frame as is. An empty dock hints nothing (its Place is a Place reach at a spot).
    private void Sync_ReachHint(FCk_Handle& InDock, const FCk_Handle_Platter& InDocked, const FCk_Handle_WorldItem& InWorldItem)
    {
        const FCk_Handle WorldItemEntity = InWorldItem;
        if (ck::IsValid(InDocked) && WorldItemEntity.Has_ReachHint())
        {
            utils_reach_hint::Set(InDock, WorldItemEntity.Get_ReachHint());
            return;
        }

        utils_reach_hint::Remove(InDock);
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
