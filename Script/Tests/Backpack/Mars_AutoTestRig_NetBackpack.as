// The backpack net tests' shared steps, on top of the net hotbar rig: a carrier whose hotbar has one bag slot and the
// backpack slot (and a Back attach point) is composed on the subject on both machines; the server lays a floor and spawns a
// pack (Mars_ItemDef_Backpack) on it under the replicated spawn owner. Each machine finds its copy of the pack near the
// floor's centre, waits for its slots to be adopted and counts the OnItemChanged its own cargo slot 0 raises.
UCLASS(Abstract)
class UMars_AutoTestRig_NetBackpack : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 24.0f;

    protected const float32 k_SettleSeconds = 1.5f;
    // The server's pause between its copy reaching a state and its next step, so the client has seen that state.
    protected const float32 k_ClientCatchUpSeconds = 2.0f;
    protected const FVector k_BackFromHand = FVector(-30.0, 0.0, -20.0);
    // Where a second world item (a food, a lantern) lies on the floor, clear of the pack.
    protected const FVector k_SideFromFloor = FVector(0.0, 300.0, 20.0);

    protected FVector _FloorTop = FVector::ZeroVector;
    protected FCk_Handle_Backpack _Pack;
    protected FCk_Handle_WorldItem _PackItem;
    protected FCk_Handle_CargoSlot _Slot0;
    // The item the test moves, as this machine knows it.
    protected FCk_Handle_Item _Item;
    protected int32 _ItemChanges = 0;
    protected int32 _EnsuresAtStart = 0;

    // Both machines: the carrier beside InFloorTop and the ensure count; the server also lays the floor.
    protected void Begin_NetBackpack(FCk_Handle InTestEntity, FVector InFloorTop)
    {
        _FloorTop = InFloorTop;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Compose_PackCarrier(InFloorTop + FVector(-200.0, 0.0, 100.0));

        if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
        { Spawn_ServerFloor(InTestEntity, InFloorTop); }
    }

    // The net world-item rig's carrier plus a Back point and the hotbar's backpack slot, so a pack can be carried and held.
    private void Compose_PackCarrier(FVector InHandLocation)
    {
        auto Subject = Get_SubjectEntity();
        auto Carrier = FMars_TESTONLY_NetCarrier();

        auto HandEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        Carrier.Hand = utils_transform::Add(HandEntity, FTransform(FRotator::ZeroRotator, InHandLocation), ECk_Replication::DoesNotReplicate);

        auto BeltEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        Carrier.Belt = utils_transform::Add(BeltEntity, FTransform(FRotator::ZeroRotator, InHandLocation + k_BeltFromHand), ECk_Replication::DoesNotReplicate);

        auto BackEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        auto Back = utils_transform::Add(BackEntity, FTransform(FRotator::ZeroRotator, InHandLocation + k_BackFromHand), ECk_Replication::DoesNotReplicate);

        auto Points = FMars_AttachPoints_Spec();
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, Carrier.Hand));
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Belt, Carrier.Belt));
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, Back));
        utils_attach_points::Add(Subject, Points);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 1;
        HotbarSpec.BackpackSlot = ECk_EnableDisable::Enable;
        Carrier.Hotbar = utils_hotbar::Add(Subject, HotbarSpec);
        Carrier.HeldItem = utils_held_item::Add(Subject);
        Carrier.Use = utils_held_item_use::Add(Subject);
        _Carrier = Carrier;
    }

    // Server: the pack lying on the floor's centre.
    protected void Spawn_ServerPack()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Backpack()),
            FTransform(FRotator::ZeroRotator, _FloorTop + FVector(0.0, 0.0, 20.0)));
        Track_ForCleanup(utils_world_item::Request_SpawnWorld(Owner, Spec));
    }

    // Server: a World-mode item of InDefinition lying on the floor beside the pack, tracked for cleanup.
    protected FCk_Handle Spawn_ServerBeside(UCk_InventoryItem_Definition InDefinition)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(InDefinition),
            FTransform(FRotator::ZeroRotator, _FloorTop + k_SideFromFloor));
        auto Entity = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(Entity);
        return Entity;
    }

    // This machine's pack has adopted every slot; the first time, cargo slot 0's OnItemChanged is counted from here.
    protected bool Get_IsPackReady()
    {
        if (ck::Is_NOT_Valid(_Pack))
        { Find_Pack(); }

        if (ck::Is_NOT_Valid(_Pack) || _Pack.Get_IsReady() == false)
        { return false; }

        if (ck::Is_NOT_Valid(_Slot0))
        {
            _Slot0 = _Pack.Get_CargoSlot(0);
            _Slot0.BindTo_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
        }

        return true;
    }

    private void Find_Pack()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Candidate.Is_Backpack() == false || Candidate.Is_WorldItem() == false)
            { continue; }

            const auto Location = Get_RootLocation(Candidate);
            if (FVector2D(Location.X - _FloorTop.X, Location.Y - _FloorTop.Y).Size() > 200.0)
            { continue; }

            _Pack = Candidate.As_Backpack();
            _PackItem = Candidate.As_WorldItem();
            return;
        }
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InMaybeItem)
    {
        _ItemChanges += 1;
    }

    UFUNCTION()
    protected void Is_PackReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsPackReady());
    }

    // The pack is ready and the subject holds a rock from bag slot 0 on this machine.
    UFUNCTION()
    protected void Is_PackReadyAndRockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Ready = Get_IsCarrierReady(_Carrier) && Get_IsPackReady() && Get_SlotHolds(0, mars_items::Rock())
            && _Carrier.HeldItem.Get_CurrentItem() == _Carrier.Hotbar.Get_ItemAt(0);
        if (Ready)
        { _Item = _Carrier.Hotbar.Get_ItemAt(0); }

        Result.Set(Ready);
    }

    // Cargo slot 0 holds the item and bag slot 0 is empty on this machine.
    protected bool Get_IsStowed()
    {
        return ck::IsValid(_Slot0) && ck::IsValid(_Item) && _Slot0.Get_Item() == _Item && Get_SlotItemCount(0) == 0;
    }

    UFUNCTION()
    protected void Is_Stowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStowed());
    }

    // The item is stowed and the subject's hands are empty on this machine.
    UFUNCTION()
    protected void Is_StowedAndHandsEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStowed() && ck::Is_NOT_Valid(_Carrier.HeldItem.Get_CurrentItem()));
    }

    // Cargo slot 0 is empty and the subject's hotbar holds the item on this machine.
    UFUNCTION()
    protected void Is_TakenBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Slot0) && ck::IsValid(_Item) && _Slot0.Get_IsOccupied() == false
            && _Carrier.Hotbar.TryGet_SlotIndexOf(_Item).IsSet());
    }

    // Server: the subject's held item goes into cargo slot 0 with a plain Stow (the authority's own caller).
    protected void Stow_ServerItem()
    {
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_Item));
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }
}
