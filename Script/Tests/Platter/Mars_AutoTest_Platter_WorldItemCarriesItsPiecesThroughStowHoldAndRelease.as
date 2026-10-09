// The platter world item carries its pieces through the item path: a loaded piece stays a scene-node child of the platter
// root while the platter is stowed (into the overflow, as the pickup task does it: transfer, then Carry), held in the hand
// (the selection) and released into the world, and rests at its slot under the held offset. Isolated Z band: -56000.
class UMars_AutoTest_Platter_WorldItemCarriesItsPiecesThroughStowHoldAndRelease : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(0.0, 0.0, -56000.0);

    // The spawned platter entity, under construction until it is a WorldItem and a Platter.
    private FCk_Handle _Entity;
    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_Item _Item;
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();

        auto Owner = InHandle;
        _Entity = utils_platter::Request_SpawnWorld(Owner,
            FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0))));
        _Piece = Build_Piece(FTransform(FRotator::ZeroRotator, k_Origin + FVector(300.0, 0.0, 0.0)));

        Add_Step_WaitUntil("the platter world item is constructed and its holder holds its item", n"Check_Constructed");
        Add_Step_WaitUntil("the piece is Ready", n"Check_PieceReady");
        Add_Step("load the piece", n"Step_Load");
        Add_Step_WaitUntil("the piece landed on the platter", n"Check_Landed");
        Add_Step("stow the platter into the overflow slot and carry it", n"Step_Stow");
        Add_Step_WaitUntil("the platter is Held", n"Check_Held");
        Add_Step_WaitSeconds("the hold's arrival settles", 1.0f);
        Add_Step("the piece rides the held platter at its slot", n"Step_AssertRidesInHand");
        Add_Step("release the platter", n"Step_Release");
        Add_Step_WaitUntil("the platter is back in the world", n"Check_Released");
        Add_Step("the piece is still on the released platter", n"Step_AssertStillLoaded");
        Run_Steps(InHandle);
    }

    // The FoodPiece rig's box fixture (a CPU-readable 1000 cm3 cube): Transform, RuntimeMesh and FoodPiece on a new entity
    // under the world's transient entity, tracked for cleanup.
    private FCk_Handle_FoodPiece Build_Piece(FTransform InWorld)
    {
        auto Spec = FMars_FoodPiece_Spec();
        Spec.Data.MassKg = 0.8;
        Spec.Tuners = FMars_FoodPiece_Tuners(0.0001, 0.05);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(ck::TransientEntity());
        Track_ForCleanup(Entity);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(
            TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"))));
        return utils_foodpiece::Add(Entity, Spec);
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsConstructed = ck::IsValid(_Entity) && _Entity.Is_WorldItem() && _Entity.Is_Platter();
        if (IsConstructed && ck::Is_NOT_Valid(_WorldItem))
        {
            _WorldItem = _Entity.As_WorldItem();
            _Platter = _Entity.As_Platter();
        }

        auto Res = OutResult;
        Res.Set(IsConstructed && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void Check_PieceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Piece.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _WorldItem.Get_HeldItem();
        Assert_True(_Item.Has_HandsOnly(), "the platter item is hands-only");
        Assert_True(_WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent, "the platter world item is Persistent");
        Assert_Equals_Int(_Platter.Get_Capacity(), 8, "the platter has the definition's eight slots");

        _Platter.Request_Load(FMars_Request_Platter_Load(_Piece));
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 1);
    }

    // What the pickup task does: transfer into the stow target, then Carry once the stow reports.
    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_StowTarget(_Item);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex()))
        {
            FinishFailure("stow precondition: the platter's stow target is the overflow slot");
            return;
        }

        auto Holder = _WorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnStowComplete"));
    }

    UFUNCTION()
    private void OnStowComplete(FCk_Handle_Inventory InSource,
                                FCk_Handle_Item InItem,
                                FCk_Handle_Inventory InTarget,
                                int32 InCount,
                                FCk_Handle_Item InNewItemInTarget,
                                ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        {
            FinishFailure(f"the platter's stow transfer failed with [{InResult :n}]");
            return;
        }

        _WorldItem.Request_Carry(FMars_Request_WorldItem_Carry(_Carrier));
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held);
    }

    UFUNCTION()
    private void Step_AssertRidesInHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto OverflowIndex = _Hotbar.Get_OverflowIndex();
        Assert_True(_Hotbar.Get_ItemAt(OverflowIndex) == _Item, "the overflow slot holds the platter");
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(OverflowIndex), "the overflow slot is selected");
        Assert_True(Get_MountParent() == _HandNode, "the platter hangs off the Hand node");
        Assert_True(Get_PieceParent() == Get_Root(), "the piece is still a scene-node child of the platter root");

        const UMars_ItemTrait_Presentation Presentation = mars_items::Platter().Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        const auto PlatterWorld = Presentation.Mounting.HeldOffset * HandWorld;
        const auto Metrics = utils_runtime_mesh::Get_Metrics(_Piece.Get_Geometry());
        const auto Expected = (utils_platter::Get_SlotPose(Metrics, _Platter.Get_Spec().SlotsLocal[0]) * PlatterWorld).GetLocation();
        const auto Actual = Get_PieceWorld().GetLocation();
        Assert_True(Actual.Equals(Expected, 0.5), f"the piece rests at slot 0 of the held platter ({Actual} vs {Expected})");
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WorldItem.Request_Release(FMars_Request_WorldItem_Release(
            _Item, _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex()), FVector(0.0, 0.0, 50.0), FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World && _WorldItem.Get_HeldItem() == _Item);
    }

    UFUNCTION()
    private void Step_AssertStillLoaded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_PieceParent() == Get_Root(), "the piece is still a scene-node child of the released platter's root");

        auto Body = _WorldItem.Get_Body();
        Assert_True(utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic, "the released platter's body is Dynamic");

        const auto Held = _Platter.Get_Held();
        Assert_Equals_Int(Held.Num(), 1, "the released platter still holds its piece");
        Assert_True(Held.Num() == 1 && Held[0] == _Piece, "the held piece is the loaded one");
    }

    private FCk_Handle_Transform Get_Root() const
    {
        FCk_Handle Entity = _Entity;
        return Entity.As_Transform();
    }

    private FTransform Get_PieceWorld() const
    {
        FCk_Handle Entity = _Piece;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    // Invalid while the piece is not a scene node.
    private FCk_Handle_Transform Get_PieceParent() const
    {
        FCk_Handle Entity = _Piece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    // Invalid while the platter is not scene-node attached.
    private FCk_Handle_Transform Get_MountParent() const
    {
        auto Node = _WorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }
}
