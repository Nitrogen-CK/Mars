// A whole food is an ordinary item: the meat slab's food item, spawned on a floor, composes the joint on its own entity and
// finishes construction once the joint is Ready: it is a FoodPiece wearing its display, with a Dynamic convex body, a
// Persistent world item whose holder holds a Food item that is not hands-only, a bounds fit taken from the joint and a
// pickup that outranks a platter's. A rock fills bag slot 0 and is held; the carrier picks the slab up through its own
// pickup (focus, then start): it stows to bag slot 1, not the overflow, and rides the carrier's back (Carried). Selecting
// slot 1 draws it in the hands, as a rock is: its mount is Held and the joint rides the hand at the held offset. Isolated
// origin (22000, -15000, -30000).
class UMars_AutoTest_WorldItem_AFoodItemStowsToABagSlotAndIsHeldWhenSelected : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(22000.0, -15000.0, -30000.0);

    // Under construction until it is a WorldItem whose holder holds its item.
    private FCk_Handle _Entity;
    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_Item _Item;
    private FCk_Handle_InteractTarget _PickupTarget;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Spawn_Floor(InHandle, k_Origin + FVector(200.0, 0.0, 0.0));

        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto Owner = ck::TransientEntity();
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_FoodItem_EntityScript, SpawnParams);
        _Entity = Pending.Get_EntityUnderConstruction();
        Track_ForCleanup(_Entity);

        Add_Step_WaitUntil("the rock holder is seeded", n"Check_HoldersSeeded", 0, 5.0f);
        Add_Step_WaitUntil("the food item is constructed and its holder holds its item", n"Check_Constructed", 0, 10.0f);
        Add_Step_WaitUntil("its body is added", n"Check_BodyAdded", 0, 5.0f);
        Add_Step("the food item is the joint: FoodPiece, display, Dynamic body, Persistent world item, bounds fit", n"Step_AssertComposed");
        Add_Step("stow the rock into bag slot 0", n"Step_StowFirst");
        Add_Step_WaitUntil("the rock is held from slot 0", n"Check_RockHeld", 0, 5.0f);
        Add_Step("the carrier focuses the food's pickup", n"Step_Focus");
        Add_Step_WaitFrames("the pickup's target enters Focused", 3);
        Add_Step("the carrier picks the food up", n"Step_PickUp");
        Add_Step_WaitUntil("the food is stowed to slot 1 and rides the back", n"Check_OnTheBack", 0, 5.0f);
        Add_Step("slot 1 holds it, not the overflow; the rock stays in the hands", n"Step_AssertStowed");
        Add_Step("select slot 1", n"Step_SelectFood");
        Add_Step_WaitUntil("the food is Held in the hand", n"Check_Held", 0, 5.0f);
        Add_Step_WaitSeconds("the hold's arrival settles", 1.0f);
        Add_Step("the selected slot holds it and the joint rides the hand", n"Step_AssertRidesTheHand");
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

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsConstructed = ck::IsValid(_Entity) && _Entity.Is_WorldItem() && ck::IsValid(_Entity.As_WorldItem().Get_HeldItem());
        if (IsConstructed && ck::Is_NOT_Valid(_WorldItem))
        {
            _WorldItem = _Entity.As_WorldItem();
            _Item = _WorldItem.Get_HeldItem();
            auto Pickup = _WorldItem.Get_Pickup();
            _PickupTarget = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        }

        auto Res = OutResult;
        Res.Set(IsConstructed);
    }

    UFUNCTION()
    private void Check_BodyAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Body = _WorldItem.Get_Body();
        auto Res = OutResult;
        Res.Set(ck::IsValid(Body) && utils_jolt_body::Get_IsBodyAdded(Body));
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Entity.Is_FoodPiece(), "the food item's entity is a FoodPiece");
        const auto Piece = _Entity.As_FoodPiece(ECk_SanityCheck::UnChecked);
        Assert_True(ck::IsValid(Piece) && Piece.Get_Status() == EMars_FoodPiece_Status::Ready, "the joint is Ready");
        Assert_True(ck::IsValid(Piece) && Piece.Get_IsWhole(), "the joint is whole");
        Assert_True(ck::IsValid(Piece) && Piece.Get_Definition().Get() == mars::Food_MeatSlab_Mars, "the joint is the meat slab's");
        Assert_True(_Entity.Is_RuntimeMeshDisplay(), "the joint wears its display");

        const auto Body = _WorldItem.Get_Body();
        Assert_True(ck::IsValid(Body) && Body == _Entity.As_JoltBody(ECk_SanityCheck::UnChecked), "the world item's body is the joint's own");
        Assert_True(ck::IsValid(Body) && utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic, "the body is Dynamic");

        Assert_True(_WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent, "the world item is Persistent");
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World, "it lies in the world");
        Assert_True(_Item.Has_Food() && _Item.Get_Food().Food == mars::Food_MeatSlab_Mars, "its item carries the meat slab's Food trait");
        Assert_False(_Item.Has_HandsOnly(), "its item is not hands-only");
        Assert_True(_Item.Get_PersistentWorldItem() == _WorldItem, "its item links back to it");

        if (ck::IsValid(Piece))
        {
            const auto Metrics = utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry());
            const auto Fit = _WorldItem.Get_BoundsFit();
            const auto Expected = (Metrics.Get_BoundsMaxCm() - Metrics.Get_BoundsMinCm()) * 0.5;
            Assert_True(Fit.HalfExtents.Equals(Expected, 0.01), f"the bounds fit spans the joint ({Fit.HalfExtents} vs {Expected})");
            Assert_True(Fit.Centre.Equals((Metrics.Get_BoundsMaxCm() + Metrics.Get_BoundsMinCm()) * 0.5, 0.01), "the bounds fit centres on the joint");
        }

        auto Pickup = _WorldItem.Get_Pickup();
        Assert_Equals_Int(Pickup.Get_FocusPriority(), constants_food_item::k_FocusPriority, "the pickup outranks a platter's");
        Assert_Valid(_PickupTarget, "the pickup has a Use target");
    }

    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(0) == _Items[0] && _Hotbar.Get_SelectedIndex() == TOptional<int32>(0)
            && _HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _WorldItem.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    UFUNCTION()
    private void Step_PickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PickupTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_OnTheBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(1) == _Item && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried
            && Get_MountParent() == _BackNode);
    }

    UFUNCTION()
    private void Step_AssertStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(_Hotbar.Get_OverflowIndex())), "the overflow slot is empty");
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "slot 0 stays selected");
        Assert_True(_HeldItem.Get_CurrentItem() == _Items[0], "the rock stays in the hands");
        Assert_True(_WorldItem.Get_Carrier() == _Carrier, "the carrier carries the food");
    }

    UFUNCTION()
    private void Step_SelectFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && Get_MountParent() == _HandNode);
    }

    UFUNCTION()
    private void Step_AssertRidesTheHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(1), "slot 1 is selected");
        Assert_True(_Hotbar.TryGet_SelectedFood() == _Item, "the hotbar's selected food is the slab");
        Assert_True(_HeldItem.Get_CurrentItem() == _Item, "the held item is the slab");
        Assert_True(_WorldItem.Get_Carrier() == _Carrier, "the carrier holds it");

        auto Body = _WorldItem.Get_Body();
        Assert_True(utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic, "the held body reads Kinematic");

        const UMars_ItemTrait_Presentation Presentation = mars_items::Food_MeatSlab().Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        const auto Expected = (Presentation.Mounting.HeldOffset * HandWorld).GetLocation();
        const auto JointWorld = utils_transform::Get_EntityCurrentTransform(_Entity.As_Transform());
        Assert_True(JointWorld.GetLocation().Equals(Expected, 0.5), f"the joint sits at the held offset ({JointWorld.GetLocation()} vs {Expected})");
    }

    // Invalid while the world item is not scene-node attached.
    private FCk_Handle_Transform Get_MountParent() const
    {
        auto Node = _WorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }
}
