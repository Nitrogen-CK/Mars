// Commits the new held item, replaces its Visual-mode world item, then broadcasts OnHeldItemChanged. An unchanged item
// only records the (possibly different, empty) selected slot.
//
// A Persistent item (one whose item carries FMars_Fragment_Item_PersistentWorldItem) is never respawned: its own World-mode
// world item is asked to Hold (onto the hand) when it becomes held and to Carry (back onto its carry point) when it stops
// being held while still in the hand. PresentationEntity then names that world item, which HeldItem does not own and
// never destroys.
//
// Only the LAST queued SetSlot is applied: each one is a full snapshot of the selection, and applying the earlier ones
// would spawn and destroy an intermediate visual and broadcast a held item that was never current at a drain.
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

        TArray<FMars_Request_HeldItem_SetSlot> SetSlotRequests = InRequests.SetSlotRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HeldItem_Requests);

        if (SetSlotRequests.Num() > 0)
        { HandleSetSlotRequest(Self, InState, SetSlotRequests.Last()); }
    }

    private void HandleSetSlotRequest(FCk_Handle_HeldItem& InHeldItem, FMars_Fragment_HeldItem& InState, const FMars_Request_HeldItem_SetSlot& InRequest)
    {
        InState.CurrentInventory = InRequest.Inventory;

        const auto PrevItem = InState.CurrentItem;
        if (InRequest.Item == PrevItem)
        { return; }

        FCk_Handle Player = InHeldItem;

        const auto PrevIsPersistent = ck::IsValid(PrevItem) && PrevItem.Has_PersistentWorldItem();
        if (PrevIsPersistent)
        {
            // Released (dropped / thrown) items read World here and stay where they are.
            auto PrevWorldItem = PrevItem.Get_PersistentWorldItem();
            if (ck::IsValid(PrevWorldItem) && PrevWorldItem.Get_TargetMount() == EMars_WorldItem_Mount::Held)
            { PrevWorldItem.Request_Carry(FMars_Request_WorldItem_Carry(Player)); }
        }
        else if (ck::IsValid(InState.PresentationEntity))
        { utils_entity_lifetime::Request_DestroyEntity(InState.PresentationEntity); }

        InState.PresentationEntity = FCk_Handle();
        InState.CurrentItem = InRequest.Item;

        auto NewItem = InRequest.Item;
        if (ck::IsValid(NewItem) && NewItem.Has_PersistentWorldItem())
        {
            auto NewWorldItem = NewItem.Get_PersistentWorldItem();
            const auto HasWorldItem = ck::IsValid(NewWorldItem);
            ck::EnsureIfNot(HasWorldItem, f"[HeldItem] Persistent item [{NewItem.ToString()}] has lost its world item");

            if (HasWorldItem)
            {
                NewWorldItem.Request_Hold(FMars_Request_WorldItem_Hold(Player));
                InState.PresentationEntity = FCk_Handle(NewWorldItem);
            }
        }
        else if (ck::IsValid(NewItem) && NewItem.Has_Presentation())
        { InState.PresentationEntity = SpawnVisual(InHeldItem, NewItem); }

        if (InHeldItem.Has_Fragment(FMars_Fragment_HeldItem_Signals))
        { InHeldItem.Get_Fragment(FMars_Fragment_HeldItem_Signals).OnHeldItemChanged.Broadcast(InHeldItem, PrevItem, NewItem); }
    }

    // Spawned at its final held pose (offset composed onto the hand) so the first rendered frame is already at rest;
    // the world item then scene-node-parents itself under the hand. Owned by the player, so it dies with it.
    // Two one-shot start poses, exclusive: the gloves' FMars_Fragment_HeldItem_SpawnFrom (a pickup riding in; the offset
    // then carries that pose) wins over the item's ArriveFrom stamp (taken from a cargo slot; lerps to HeldOffset). The
    // stamp is consumed either way so it never animates a later spawn.
    private FCk_Handle SpawnVisual(FCk_Handle_HeldItem& InHeldItem, FCk_Handle_Item& InItem)
    {
        auto Hand = InHeldItem.Get_HandAttachPoint();
        if (ck::EnsureIfNot(ck::IsValid(Hand), f"[HeldItem] [{InHeldItem.ToString()}] has no hand attach point"))
        { return FCk_Handle(); }

        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();

        TSubclassOf<UMars_WorldItem_EntityScript> ScriptClass = UMars_WorldItem_EntityScript;
        if (ck::IsValid(Presentation.WorldItemScriptClass))
        { ScriptClass = Presentation.WorldItemScriptClass; }

        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(Hand);
        auto SpawnTransform = Presentation.HeldOffset * HandWorld;
        auto AttachOffset = Presentation.HeldOffset;
        const auto HasSpawnFrom = InHeldItem.Has_Fragment(FMars_Fragment_HeldItem_SpawnFrom);
        if (HasSpawnFrom)
        {
            SpawnTransform = InHeldItem.Get_Fragment(FMars_Fragment_HeldItem_SpawnFrom).WorldTransform;
            AttachOffset = SpawnTransform.GetRelativeTransform(HandWorld);
            InHeldItem.Request_TryRemove(FMars_Fragment_HeldItem_SpawnFrom);
        }

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = SpawnTransform;
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(InItem.Get_Definition());
        SpawnParams.Mode = EMars_WorldItem_Mode::Visual;
        SpawnParams.AttachTo = Hand;
        SpawnParams.AttachOffset = AttachOffset;

        // Taken out of a cargo slot (or anything else that stamped it): start where the item visually was and lerp in.
        const auto ArriveFrom = InItem.TryConsume_ArriveFrom();
        if (ArriveFrom.IsSet && HasSpawnFrom == false)
        {
            SpawnParams.ArriveFrom = ArriveFrom;
            SpawnParams.SpawnTransform = ArriveFrom.World;
        }

        FCk_Handle Owner = InHeldItem;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, ScriptClass, SpawnParams);
        return Pending.Get_EntityUnderConstruction();
    }
}
