// Once per hotbar, on every machine: requests one slot root per layout index under the carrier. The class follows the
// carrier: the replicated slot when the carrier has a replication driver (the authority builds it and stamps the
// host-side check; a client's request is the placeholder the replicated slot resolves to), the local twin when it has
// none (a test rig). No wait for the driver is needed: a carrier gets its driver no later than its own construction,
// before Construct for a plain script and inside it for an actor-bridged one (OwningActor's Add), and on a client a
// replicated carrier is built by its driver; Add runs on a constructed carrier, so what Has says here is final.
class UMars_Processor_Hotbar_SpawnSlots : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Hotbar_NeedsSlots;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hotbar);
        Query.Require(FMars_Tag_Hotbar_NeedsSlots);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Hotbar = InHandle.As_Hotbar();
        Hotbar.Request_TryRemove(FMars_Tag_Hotbar_NeedsSlots);

        const auto Replicated = utils_entity_replication_driver::Has(InHandle);
        TSubclassOf<UMars_HotbarSlot_EntityScript> SlotClass = UMars_HotbarSlot_EntityScript;
        if (Replicated == false)
        { SlotClass = UMars_HotbarSlot_Local_EntityScript; }

        for (int32 Index = 0; Index <= Hotbar.Get_LastIndex(); ++Index)
        {
            auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, SlotClass,
                FMars_HotbarSlot_SpawnParams(Index, Hotbar.Get_SlotKind(Index)));

            if (Replicated)
            {
                auto Slot = Pending.Get_EntityUnderConstruction();
                utils_net_spawn::Expect_Replicated(Slot);
            }
        }
    }
}

// Every frame until the hotbar is ready, on every machine: finds the carrier's slot roots among its lifetime dependents
// and records each slot's inventory at its index; the hotbar is ready (OnReady) once every index is filled. A slot root that does
// not fit the layout (an index out of range or taken, a kind that disagrees, a class that does not follow the carrier)
// ensures and is destroyed. Never pumped: a slot still in flight is looked for again next frame.
class UMars_Processor_Hotbar_AdoptSlots : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Hotbar_SpawnSlots");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hotbar);
        Query.Require(FMars_Fragment_Hotbar_AwaitingSlots);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Hotbar_Local& InLocal)
    {
        auto Hotbar = InHandle.As_Hotbar();
        const auto CarrierReplicates = utils_entity_replication_driver::Has(InHandle);

        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(InHandle))
        {
            if (ck::Is_NOT_Valid(Dependent) || Dependent.Has_Fragment(FMars_Fragment_HotbarSlot) == false)
            { continue; }

            if (utils_entity_lifetime::Get_IsPendingDestroy(Dependent, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            const auto Slot = Dependent.Get_Fragment(FMars_Fragment_HotbarSlot);
            if (InLocal.Slots.IsValidIndex(Slot.Index) && InLocal.Slots[Slot.Index] == Slot.Inventory)
            { continue; }

            const auto FollowsCarrier = utils_entity_replication_driver::Has(Dependent) == CarrierReplicates;
            if (ck::EnsureIfNot(FollowsCarrier && Get_Fits(Hotbar, InLocal, Slot),
                f"[Hotbar] [{Hotbar.ToString()}] found slot root [{Dependent.ToString()}] (index {Slot.Index}, {Slot.Kind :n}) "
                + f"that does not fit its layout of {InLocal.Slots.Num()} slots: out of range, taken, of another kind, or of a "
                + "class that does not follow the carrier's replication. Destroyed."))
            {
                utils_entity_lifetime::Request_DestroyEntity(Dependent);
                continue;
            }

            InLocal.Slots[Slot.Index] = Slot.Inventory;
        }

        for (const auto& Slot : InLocal.Slots)
        {
            if (ck::Is_NOT_Valid(Slot))
            { return; }
        }

        Hotbar.Request_TryRemove(FMars_Fragment_Hotbar_AwaitingSlots);

        if (Hotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals) == false)
        { return; }

        // Handlers build the hotbar's widget: scope the script world to the hotbar's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(Hotbar));
        Hotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnReady.Broadcast(Hotbar);
    }

    // InSlot's index is in the layout and still free, and its kind is the layout's there.
    private bool Get_Fits(const FCk_Handle_Hotbar& InHotbar, const FMars_Fragment_Hotbar_Local& InLocal,
                          const FMars_Fragment_HotbarSlot& InSlot) const
    {
        if (InLocal.Slots.IsValidIndex(InSlot.Index) == false)
        { return false; }

        return ck::Is_NOT_Valid(InLocal.Slots[InSlot.Index]) && InHotbar.Get_SlotKind(InSlot.Index) == InSlot.Kind;
    }
}

// Once per hotbar: the authority drops the mirror (its own drain broadcasts). A client binds the ledger's rep-notify
// and reconciles once, so a value that replicated before the bind still broadcasts; each reconcile diffs the arrived
// ledger against the last one it saw and raises the signals the authority raised: OnSelectionChanged when the selection
// changed, OnOverflowEjectRequested when the eject serial advanced and the park it counted still stands. A park the
// authority already resolved is history: a hotbar composed after it must not answer it with a drop.
class UMars_Processor_Hotbar_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Hotbar_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hotbar);
        Query.Require(FMars_Tag_Hotbar_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Hotbar = InHandle.As_Hotbar();
        Hotbar.Request_TryRemove(FMars_Tag_Hotbar_NeedsMirror);

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Hotbar.Request_TryRemove(FMars_Fragment_Hotbar_Mirror);
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Hotbar, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Hotbar);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Hotbar() == false)
        { return; }

        auto Hotbar = InHandle.As_Hotbar();
        Reconcile(Hotbar);
    }

    private void Reconcile(FCk_Handle_Hotbar& InHotbar)
    {
        auto& Mirror = InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Mirror);
        const auto Last = Mirror.Last;
        const auto Now = InHotbar.Get_Fragment(FMars_Fragment_Hotbar);
        Mirror.Last = Now;

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals) == false)
        { return; }

        // Handlers mark the widget's selection and drop an overflow: scope the script world to the hotbar's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InHotbar));

        if ((Now.SelectedIndex == Last.SelectedIndex) == false)
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSelectionChanged.Broadcast(InHotbar); }

        if (Now.EjectSerial > Last.EjectSerial && Now.Park == EMars_Hotbar_Park::Parked)
        {
            const auto OverflowItem = InHotbar.Get_ItemAt(InHotbar.Get_OverflowIndex());
            InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnOverflowEjectRequested.Broadcast(InHotbar, OverflowItem);
        }
    }
}
