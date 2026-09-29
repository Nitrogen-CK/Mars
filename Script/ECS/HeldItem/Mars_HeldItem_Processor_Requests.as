// Commits the new held item, replaces its HeldVisual world item, then broadcasts OnHeldItemChanged. An unchanged item
// only records the (possibly different, empty) selected slot.
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

        const auto HasSetSlot = InRequests.SetSlot.IsSet();
        auto SetSlot = HasSetSlot ? InRequests.SetSlot.GetValue() : FMars_Request_HeldItem_SetSlot();

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HeldItem_Requests);

        if (HasSetSlot)
        { HandleSetSlotRequest(Self, InState, SetSlot); }
    }

    private void HandleSetSlotRequest(FCk_Handle_HeldItem& InHeldItem, FMars_Fragment_HeldItem& InState, const FMars_Request_HeldItem_SetSlot& InRequest)
    {
        InState.CurrentInventory = InRequest.Inventory;

        const auto PrevItem = InState.CurrentItem;
        if (InRequest.Item == PrevItem)
        { return; }

        if (ck::IsValid(InState.PresentationEntity))
        { utils_entity_lifetime::Request_DestroyEntity(InState.PresentationEntity); }

        InState.PresentationEntity = FCk_Handle();
        InState.CurrentItem = InRequest.Item;

        auto NewItem = InRequest.Item;
        if (ck::IsValid(NewItem) && NewItem.Has_Presentation())
        { InState.PresentationEntity = SpawnHeldVisual(InHeldItem, NewItem); }

        if (InHeldItem.Has_Fragment(FMars_Fragment_HeldItem_Signals))
        { InHeldItem.Get_Fragment(FMars_Fragment_HeldItem_Signals).OnHeldItemChanged.Broadcast(InHeldItem, PrevItem, NewItem); }
    }

    // Spawned at its final held pose (offset composed onto the hand) so the first rendered frame is already at rest;
    // the world item then scene-node-parents itself under the hand. Owned by the player, so it dies with it.
    private FCk_Handle SpawnHeldVisual(FCk_Handle_HeldItem& InHeldItem, FCk_Handle_Item& InItem)
    {
        auto Hand = InHeldItem.Get_HandAttachPoint();
        if (ck::EnsureIfNot(ck::IsValid(Hand), f"[HeldItem] [{InHeldItem.ToString()}] has no hand attach point"))
        { return FCk_Handle(); }

        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();

        TSubclassOf<UMars_WorldItem_EntityScript> ScriptClass = UMars_WorldItem_EntityScript;
        if (ck::IsValid(Presentation.WorldItemScriptClass))
        { ScriptClass = Presentation.WorldItemScriptClass; }

        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(Hand);
        const auto SpawnTransform = Presentation.HeldOffset * HandWorld;

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = SpawnTransform;
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(InItem.Get_Definition());
        SpawnParams.Mode = EMars_WorldItem_Mode::HeldVisual;
        SpawnParams.AttachTo = Hand;
        SpawnParams.AttachOffset = Presentation.HeldOffset;

        FCk_Handle Owner = InHeldItem;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, ScriptClass, SpawnParams);
        return Pending.Get_EntityUnderConstruction();
    }
}
