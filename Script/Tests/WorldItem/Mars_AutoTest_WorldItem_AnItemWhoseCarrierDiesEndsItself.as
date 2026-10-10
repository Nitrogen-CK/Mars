// A world item ends with the carrier its item rides. A carrier (a child of the test entity: Hand and Back nodes, a hotbar
// with one bag slot) takes a meat slab into its empty hands (the slab's holder -> bag slot 0, selected: Held on the Hand).
// The carrier is then destroyed: its hotbar slots and the slab's item go with it, and within three frames the slab's world
// item is going too (invalid or pending destroy), with nothing ensuring. Isolated origin (53200, -12000, -30000).
class UMars_AutoTest_WorldItem_AnItemWhoseCarrierDiesEndsItself : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(53200.0, -12000.0, -30000.0);
    private const FVector k_SlabOffset = FVector(200.0, 0.0, 0.0);
    // The slab's construction waits for its joint to import.
    private const int32 k_SlowPolls = 900;
    // The carrier's teardown, the slab's item ending with its hotbar slot and the world item's reconcile ending it: the
    // header's three frames, read on the poll after them (where the assertion after a three-frame settle read them).
    private const int32 k_MaxFramesToFollow = 4;

    private FCk_Handle _SlabEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_Item _SlabItem;
    // The frame the destroy was requested, and the frame the slab's world item was first seen going.
    private int64 _DestroyFrame = -1;
    private int64 _FollowedSeenFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Carrier = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Add_CarrierBodyWithBack(Carrier, k_Origin);
        Add_Hotbar(_Carrier, 1);

        Spawn_Floor(InHandle, k_Origin + k_SlabOffset);
        auto SlabParams = UMars_FoodItem_EntityScript::Params();
        SlabParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_SlabOffset + FVector(0.0, 0.0, 5.0));
        SlabParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SlabParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        _SlabEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SlabParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_SlabEntity);

        Add_Step_WaitUntil("the slab is constructed, its item linked", n"Check_Constructed", k_SlowPolls, 0);
        Add_Step("take the slab: its holder -> bag slot 0", n"Step_TakeSlab");
        Add_Step_WaitUntil("the slab settles Held on the Hand", n"Check_SlabHeld", 0, 0);
        Add_Step("destroy the carrier", n"Step_DestroyCarrier");
        Add_Step_WaitUntil("the slab's world item follows its item", n"Check_SlabFollowed", 0, 0);
        Add_Step("the slab's item and its world item are both going", n"Step_AssertEnded");
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
        const auto SlabReady = ck::IsValid(_SlabEntity) && _SlabEntity.Is_WorldItem() && ck::IsValid(_SlabEntity.As_WorldItem().Get_Item());
        if (SlabReady && ck::Is_NOT_Valid(_Slab))
        {
            _Slab = _SlabEntity.As_WorldItem();
            _SlabItem = _Slab.Get_Item();
        }

        auto Res = OutResult;
        Res.Set(SlabReady);
    }

    UFUNCTION()
    private void Step_TakeSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Holder = _Slab.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_SlabItem, _Hotbar.Get_Slot(0)),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnTakeAnswered"));
    }

    UFUNCTION()
    private void OnTakeAnswered(FCk_Handle_Inventory InSource,
                                FCk_Handle_Item InItem,
                                FCk_Handle_Inventory InTarget,
                                int32 InCount,
                                FCk_Handle_Item InNewItemInTarget,
                                ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        { FinishFailure(f"the take's transfer failed with [{InResult :n}]"); }
    }

    UFUNCTION()
    private void Check_SlabHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::Held && _Slab.Get_Carrier() == _Carrier && _Slab.Get_IsSettled());
    }

    UFUNCTION()
    private void Check_SlabFollowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_IsGoing(_SlabEntity) == false)
        {
            Res.Set(false);
            return;
        }

        _FollowedSeenFrame = utils_time::Get_FrameCounter();
        Res.Set(true);
    }

    UFUNCTION()
    private void Step_DestroyCarrier(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Carrier);
        _DestroyFrame = utils_time::Get_FrameCounter();
    }

    UFUNCTION()
    private void Step_AssertEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsGoing(_SlabItem), "the slab's item went with the carrier's hotbar slot");
        Assert_True(Get_IsGoing(_SlabEntity), "the slab's world item ended with its item");

        const auto Frames = _FollowedSeenFrame - _DestroyFrame;
        Assert_True(Frames <= k_MaxFramesToFollow,
            f"the slab's world item was going within {k_MaxFramesToFollow} frames of the destroy (took {Frames})");
    }

    private bool Get_IsGoing(FCk_Handle InEntity) const
    {
        return ck::Is_NOT_Valid(InEntity) || utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }
}
