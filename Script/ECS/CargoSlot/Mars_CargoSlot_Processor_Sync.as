// Polls each slot's item against the last pass (the Hotbar sync shape). A change destroys the old cargo visual, spawns
// one for the new item (a Visual-mode world item under the slot node at Presentation.CargoOffset, arriving from the
// item's ArriveFrom stamp when there is a fresh one), then broadcasts OnItemChanged.
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
        auto Now = utils_cargo_slot::DoGet_FirstItem(InState.Inventory);
        if (Now == InState.LastSeen)
        { return; }

        InState.LastSeen = Now;

        if (ck::IsValid(InState.Visual))
        { utils_entity_lifetime::Request_DestroyEntity(InState.Visual); }

        InState.Visual = FCk_Handle();

        if (ck::IsValid(Now) && Now.Has_Presentation())
        { InState.Visual = SpawnVisual(InHandle, Now); }

        auto Self = InHandle.As_CargoSlot();
        if (Self.Has_Fragment(FMars_Fragment_CargoSlot_Signals))
        { Self.Get_Fragment(FMars_Fragment_CargoSlot_Signals).OnItemChanged.Broadcast(Self, Now); }
    }

    // Owned by the slot entity, so it dies with the pack. Spawned at its rest pose (or its ArriveFrom pose) so the first
    // rendered frame is already where it belongs.
    private FCk_Handle SpawnVisual(FCk_Handle& InSlot, FCk_Handle_Item& InItem)
    {
        auto SlotNode = InSlot.As_Transform();
        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();

        const auto SlotWorld = utils_transform::Get_EntityCurrentTransform(SlotNode);

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = Presentation.CargoOffset * SlotWorld;
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(InItem.Get_Definition());
        SpawnParams.Mode = EMars_WorldItem_Mode::Visual;
        SpawnParams.AttachTo = InSlot;
        SpawnParams.AttachOffset = Presentation.CargoOffset;

        // Stowed out of a hand (or anything else that stamped it): start where the item visually was and lerp in.
        SpawnParams.ArriveFrom = InItem.TryConsume_ArriveFrom();
        if (SpawnParams.ArriveFrom.IsSet)
        { SpawnParams.SpawnTransform = SpawnParams.ArriveFrom.World; }

        auto Pending = utils_entity_script::Request_SpawnEntity(InSlot, utils_world_item::Get_WorldItemScriptClass(InItem), SpawnParams);
        return Pending.Get_EntityUnderConstruction();
    }
}
