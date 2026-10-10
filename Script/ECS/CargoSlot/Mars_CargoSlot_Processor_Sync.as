// Polls each slot's item against the last pass (the Hotbar sync shape). A change destroys the old cargo visual, spawns
// one for the new item (a Visual-mode world item under the slot node at Presentation.Mounting.CargoOffset, arriving from where a
// fresh stow said it was), then broadcasts OnItemChanged. A Persistent item gets no visual: the stow carried its own world
// item onto the slot's node (UMars_Processor_CargoSlot_HandleRequests).
class UMars_Processor_CargoSlot_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CargoSlot);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_CargoSlot& InState)
    {
        auto Now = InState.Inventory.Get_SoleItem();
        if (Now == InState.LastSeen)
        { return; }

        InState.LastSeen = Now;

        if (ck::IsValid(InState.Visual))
        { utils_entity_lifetime::Request_DestroyEntity(InState.Visual); }

        InState.Visual = FCk_Handle();

        if (ck::IsValid(Now) && Now.Has_Presentation() && Now.Has_PersistentWorldItem() == false)
        { InState.Visual = SpawnVisual(InHandle, InState, Now); }

        auto Self = InHandle.As_CargoSlot();
        if (Self.Has_Fragment(FMars_Fragment_CargoSlot_Signals))
        { Self.Get_Fragment(FMars_Fragment_CargoSlot_Signals).OnItemChanged.Broadcast(Self, Now); }
    }

    // Owned by the slot entity, so it dies with the pack. The item's pending arrival is consumed here either way.
    private FCk_Handle SpawnVisual(FCk_Handle& InSlot, FMars_Fragment_CargoSlot& InState, FCk_Handle_Item& InItem)
    {
        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();

        auto Visual = FMars_WorldItem_VisualSpec(InItem, InSlot.As_Transform(), Presentation.Mounting.CargoOffset);
        if (InState.PendingArrival.IsSet() && InState.PendingArrival.GetValue().Item == InItem)
        {
            Visual.ArriveFrom = utils_world_item::Get_FreshArrival(InState.PendingArrival.GetValue());
            InState.PendingArrival.Reset();
        }

        return utils_world_item::Request_SpawnVisual(InSlot, Visual);
    }
}
