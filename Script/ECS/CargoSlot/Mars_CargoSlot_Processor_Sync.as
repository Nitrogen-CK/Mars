// Polls each slot's item against the last pass (the Hotbar sync shape). A change consumes the pending arrival, destroys
// the old cargo visual, spawns one for the new item (a Visual-mode world item under the slot node at
// Presentation.Mounting.CargoOffset, arriving from where a fresh stow said it was; owned by the slot entity, so it dies
// with the pack), then broadcasts OnItemChanged. A Persistent item gets no visual: its own world item mounts on the slot's
// node (UMars_Processor_WorldItem_Reconcile).
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
        const auto Arrival = utils_world_item::Consume_PendingArrival(InState.PendingArrival, Now);

        if (ck::IsValid(InState.Visual))
        { utils_entity_lifetime::Request_DestroyEntity(InState.Visual); }

        InState.Visual = FCk_Handle();

        if (ck::IsValid(Now) && Now.Has_Presentation() && Now.Has_PersistentWorldItem() == false)
        {
            const UMars_ItemTrait_Presentation Presentation = Now.Get_Presentation();
            auto Visual = FMars_WorldItem_VisualSpec(Now, InHandle.As_Transform(), Presentation.Mounting.CargoOffset);
            Visual.ArriveFrom = Arrival;
            InState.Visual = utils_world_item::Request_SpawnVisual(InHandle, Visual);
        }

        auto Self = InHandle.As_CargoSlot();
        if (Self.Has_Fragment(FMars_Fragment_CargoSlot_Signals))
        { Self.Get_Fragment(FMars_Fragment_CargoSlot_Signals).OnItemChanged.Broadcast(Self, Now); }
    }
}
