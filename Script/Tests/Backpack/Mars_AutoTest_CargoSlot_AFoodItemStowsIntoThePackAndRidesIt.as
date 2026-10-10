// A food item stows into a worn pack's cargo slot and rides it. The carrier (Hand and Back nodes, Hotbar with a backpack
// slot, HeldItem) wears a backpack (its item in the backpack slot, its world item Carried on the back) and picks the meat
// slab up into its bag slot. Cargo slot 0 offers Stow; the stow moves the item into the slot and carries the slab's own
// world item onto the slot's node: no cargo visual, the slab is Carried by the slot, its parent chain reaches the pack's
// root and the bag slot is empty. Taking it back out lands it in the selected bag slot and the hands hold it again: Held,
// on the hand. Isolated origin (28000, -29000, -30000).
class UMars_AutoTest_CargoSlot_AFoodItemStowsIntoThePackAndRidesIt : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(28000.0, -29000.0, -30000.0);
    private const FVector k_PackOffset = FVector(200.0, -150.0, 0.0);
    private const FVector k_FoodOffset = FVector(200.0, 150.0, 0.0);
    // A scene-node chain longer than this from the slab is not the pack's.
    private const int32 k_MaxChainLength = 8;

    private FCk_Handle _PackEntity;
    private FCk_Handle_Backpack _Backpack;
    private FCk_Handle_WorldItem _PackWorldItem;
    private FCk_Handle_CargoSlot _Slot0;

    private FCk_Handle _FoodEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_Item _SlabItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();

        Spawn_Floor(InHandle, k_Origin + k_PackOffset);
        auto PackParams = UMars_Backpack_EntityScript::Params();
        PackParams.Definition = mars_items::Backpack();
        PackParams.Mode = EMars_WorldItem_Mode::World;
        PackParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_PackOffset + FVector(0.0, 0.0, 20.0));
        auto PackPending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, PackParams);
        _PackEntity = PackPending.Get_EntityUnderConstruction();

        Spawn_Floor(InHandle, k_Origin + k_FoodOffset);
        auto FoodParams = UMars_FoodItem_EntityScript::Params();
        FoodParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        FoodParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        FoodParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, FoodParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the pack and the slab are constructed", n"Check_Constructed", 0, 10.0f);
        Add_Step("the carrier puts the pack on", n"Step_WearPack");
        Add_Step_WaitUntil("the pack is worn: Carried on the back", n"Check_PackWorn", 0, 5.0f);
        Add_Step("the carrier focuses the slab's pickup", n"Step_FocusFood");
        Add_Step_WaitFrames("the slab's target enters Focused", 3);
        Add_Step("the carrier picks the slab up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the slab is Held", n"Check_SlabHeld", 0, 5.0f);
        Add_Step_WaitSeconds("the hold's arrival settles", 0.5f);
        Add_Step("cargo slot 0 offers Stow; stow the slab", n"Step_StowIntoSlot0");
        Add_Step_WaitUntil("slot 0 holds the slab and the slab rides the slot", n"Check_RidesTheSlot", 0, 5.0f);
        Add_Step("no visual; the slab hangs off the pack; the bag slot is empty", n"Step_AssertRidesThePack");
        Add_Step("take the slab back out", n"Step_TakeFromSlot0");
        Add_Step_WaitUntil("the slab is Held on the hand again", n"Check_SlabHeld", 0, 5.0f);
        Add_Step("the bag slot holds it and slot 0 is empty", n"Step_AssertTakenBack");
        Run_Steps(InHandle);
    }

    // A static slab whose top is at InTop.
    private void Spawn_Floor(FCk_Handle InOwner, FVector InTop)
    {
        auto Owner = InOwner;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(80.0, 80.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }

    // Invalid while InWorldItem is not scene-node attached.
    private FCk_Handle_Transform Get_MountParent(const FCk_Handle_WorldItem& InWorldItem) const
    {
        auto Node = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    // InEntity's scene-node parents reach InAncestor within k_MaxChainLength steps.
    private bool Get_HangsOff(FCk_Handle InEntity, FCk_Handle_Transform InAncestor) const
    {
        auto Current = InEntity;
        for (int32 Step = 0; Step < k_MaxChainLength; ++Step)
        {
            auto Node = Current.As_SceneNode(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Node))
            { return false; }

            const auto Parent = utils_scene_node::Get_Parent(Node);
            if (Parent == InAncestor)
            { return true; }

            Current = Parent;
        }

        return false;
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto PackReady = ck::IsValid(_PackEntity) && _PackEntity.Is_Backpack() && _PackEntity.Is_WorldItem()
            && ck::IsValid(_PackEntity.As_WorldItem().Get_HeldItem());
        const auto FoodReady = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem() && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem());
        if (PackReady && FoodReady && ck::Is_NOT_Valid(_Backpack))
        {
            _Backpack = _PackEntity.As_Backpack();
            _PackWorldItem = _PackEntity.As_WorldItem();
            _Slot0 = _Backpack.Get_CargoSlot(0);
            _Slab = _FoodEntity.As_WorldItem();
            _SlabItem = _Slab.Get_HeldItem();
        }

        auto Res = OutResult;
        Res.Set(PackReady && FoodReady);
    }

    // What the pickup task does for a Persistent item: transfer into the hotbar's stow target (the backpack slot), then
    // Carry once it reports.
    UFUNCTION()
    private void Step_WearPack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PackItem = _PackWorldItem.Get_HeldItem();
        const auto Target = _Hotbar.TryGet_StowTarget(PackItem);
        if (Target != _Hotbar.Get_BackpackSlot())
        {
            FinishFailure("wear precondition: the pack's stow target is the backpack slot");
            return;
        }

        auto Holder = _PackWorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(PackItem, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnPackStowed"));
    }

    UFUNCTION()
    private void OnPackStowed(FCk_Handle_Inventory InSource, FCk_Handle_Item InItem, FCk_Handle_Inventory InTarget, int32 InCount,
                              FCk_Handle_Item InNewItemInTarget, ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        {
            FinishFailure(f"the pack's stow transfer failed with [{InResult :n}]");
            return;
        }

        _PackWorldItem.Request_Carry(FMars_Request_WorldItem_Carry(_Carrier));
    }

    UFUNCTION()
    private void Check_PackWorn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PackWorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried && Get_MountParent(_PackWorldItem) == _BackNode
            && _PackWorldItem.Has_Fragment(FMars_Fragment_WorldItem_Arrival) == false);
    }

    UFUNCTION()
    private void Step_FocusFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    UFUNCTION()
    private void Step_PickUpFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_SlabHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::Held && Get_MountParent(_Slab) == _HandNode);
    }

    UFUNCTION()
    private void Step_StowIntoSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_cargo_slot::Get_CanAccept(_SlabItem), "a cargo slot accepts a food item");
        const auto Action = _Slot0.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_CargoSlot_Action::Stow, f"Get_ActionFor(carrier holding the slab) on an empty slot (got [{Action :n}])");
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_SlabItem));
    }

    UFUNCTION()
    private void Check_RidesTheSlot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle SlotEntity = _Slot0;
        auto Res = OutResult;
        Res.Set(_Slot0.Get_Item() == _SlabItem && _Slab.Get_Mount() == EMars_WorldItem_Mount::Carried && _Slab.Get_Carrier() == SlotEntity
            && _Slab.Has_Fragment(FMars_Fragment_WorldItem_Arrival) == false);
    }

    UFUNCTION()
    private void Step_AssertRidesThePack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle SlotEntity = _Slot0;
        FCk_Handle PackEntity = _Backpack;
        Assert_True(ck::Is_NOT_Valid(_Slot0.Get_Visual()), "a stowed food gets no cargo visual");
        Assert_True(Get_MountParent(_Slab) == SlotEntity.As_Transform(), "the slab hangs off the slot's node");
        Assert_True(Get_HangsOff(_FoodEntity, PackEntity.As_Transform()), "the slab's parent chain reaches the pack's root");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)), "the bag slot is empty");
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the hands are empty");
    }

    UFUNCTION()
    private void Step_TakeFromSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Hotbar.TryGet_TakeTarget(_SlabItem);
        if (Target != _Hotbar.Get_Slot(0))
        {
            FinishFailure("take precondition: the slab's take target is bag slot 0");
            return;
        }

        _Slot0.Request_Take(FMars_Request_CargoSlot_Take(_SlabItem, Target));
    }

    UFUNCTION()
    private void Step_AssertTakenBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_ItemAt(0) == _SlabItem, "the bag slot holds the slab");
        Assert_False(_Slot0.Get_IsOccupied(), "slot 0 is empty");
        Assert_True(_Slab.Get_Carrier() == _Carrier, "the carrier holds the slab");
    }
}
