// A food item taken off a platter while it still settles stays in the hand. The carrier picks the meat slab up, deposits it on
// a large platter (the platter drops the joint, Dynamic, into Settling), and picks it up again one frame after the drop,
// long before it could freeze. Three seconds later (past Settle.MaxSeconds) the slab is still Held with the hand as its
// parent: the freeze's attach did not pull it back onto the root. The platter forgot it silently (a first landing never
// landed): it is empty, no OnLoaded, no OnUnloaded. Isolated origin (24000, -21000, -30000).
class UMars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(24000.0, -21000.0, -30000.0);
    private const FVector k_PlatterOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);

    // Under construction until each is a WorldItem whose holder holds its item.
    private FCk_Handle _PlatterEntity;
    private FCk_Handle _FoodEntity;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_WorldItem _PlatterItem;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_Item _FoodItem;
    private FCk_Handle_FoodPiece _Joint;

    private TArray<FCk_Handle_FoodPiece> _Loaded;
    private TArray<FCk_Handle_FoodPiece> _Unloaded;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();
        Bind_PushSelection();

        auto Owner = InHandle;
        Spawn_Floor(Owner, k_Origin + k_PlatterOffset);
        _PlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            mars_items::Platter_Large()));

        Spawn_Floor(Owner, k_Origin + k_FoodOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the platter and the food item are constructed", n"Check_Constructed", 0, 10.0f);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 5.0f);
        Add_Step("the carrier focuses the food's pickup", n"Step_FocusFood");
        Add_Step_WaitFrames("the food's target enters Focused", 3);
        Add_Step("the carrier picks the food up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the food is Held", n"Check_FoodHeld", 0, 5.0f);
        Add_Step_WaitSeconds("the hold's arrival settles", 0.5f);
        Add_Step("the carrier unfocuses the food and focuses the platter", n"Step_FocusPlatter");
        Add_Step_WaitFrames("the platter's target enters Focused", 3);
        Add_Step("the carrier deposits the food on the platter", n"Step_Deposit");
        Add_Step_WaitUntil("the food is released into the world", n"Check_FoodReleased", 0, 3.0f);
        Add_Step("the carrier unfocuses the platter and focuses the food", n"Step_RefocusFood");
        Add_Step_WaitFrames("the food's target enters Focused", 3);
        Add_Step_WaitUntil("the platter dropped the joint", n"Check_Dropped", 0, 3.0f);
        Add_Step_WaitFrames("one frame after the drop", 1);
        Add_Step("the carrier takes the food while it settles", n"Step_TakeWhileSettling");
        Add_Step_WaitUntil("the food is Held again", n"Check_FoodHeld", 0, 5.0f);
        Add_Step_WaitSeconds("past the longest settle", 3.0f);
        Add_Step("the food stayed in the hand and the platter is empty", n"Step_AssertStayedInTheHand");
        Run_Steps(InHandle);
    }

    // A static slab whose top is at InTop.
    private void Spawn_Floor(FCk_Handle& InOwner, FVector InTop)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InOwner);
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
        const auto PlatterReady = ck::IsValid(_PlatterEntity) && _PlatterEntity.Is_Platter()
            && ck::IsValid(_PlatterEntity.As_WorldItem().Get_HeldItem());
        const auto FoodReady = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem()
            && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem());
        if (PlatterReady && FoodReady && ck::Is_NOT_Valid(_Platter))
        {
            _Platter = _PlatterEntity.As_Platter();
            _PlatterItem = _PlatterEntity.As_WorldItem();
            _Food = _FoodEntity.As_WorldItem();
            _FoodItem = _Food.Get_HeldItem();
            _Joint = _FoodEntity.As_FoodPiece();
            _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnLoaded"));
            _Platter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded"));
        }

        auto Res = OutResult;
        Res.Set(PlatterReady && FoodReady);
    }

    UFUNCTION()
    private void Step_FocusFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = Get_Pickup(_Food);
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    UFUNCTION()
    private void Step_PickUpFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = Get_UseTarget(_Food);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_FoodHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::Held && Get_Parent(_Food) == _HandNode);
    }

    UFUNCTION()
    private void Step_FocusPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto FoodPickup = Get_Pickup(_Food);
        FoodPickup.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Carrier));

        auto PlatterPickup = Get_Pickup(_PlatterItem);
        PlatterPickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    UFUNCTION()
    private void Step_Deposit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = Get_UseTarget(_PlatterItem);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_FoodReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::World && _Food.Get_HeldItem() == _FoodItem);
    }

    UFUNCTION()
    private void Step_RefocusFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto PlatterPickup = Get_Pickup(_PlatterItem);
        PlatterPickup.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Carrier));

        auto FoodPickup = Get_Pickup(_Food);
        FoodPickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    UFUNCTION()
    private void Check_Dropped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSettling());
    }

    UFUNCTION()
    private void Step_TakeWhileSettling(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSettling(), "the joint is still settling when the hand takes it");
        Assert_Equals_Int(_Loaded.Num(), 0, "the joint has not landed yet");

        auto Target = Get_UseTarget(_Food);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertStayedInTheHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::Held, "the food is still Held");
        Assert_True(Get_Parent(_Food) == _HandNode, "the food's parent is the hand, not the platter root");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is empty");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint is off the platter's books");
        Assert_Equals_Int(_Loaded.Num(), 0, "no OnLoaded: the joint never landed");
        Assert_Equals_Int(_Unloaded.Num(), 0, "no OnUnloaded: a first landing leaves silently");
    }

    UFUNCTION()
    private void OnLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _Loaded.Add(InPiece);
    }

    UFUNCTION()
    private void OnUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _Unloaded.Add(InPiece);
    }

    private bool Get_IsSettling() const
    {
        for (const auto& Settling : _Platter.Get_Fragment(FMars_Fragment_Platter).Settling)
        {
            if (Settling.Piece == _Joint)
            { return true; }
        }

        return false;
    }

    private FCk_Handle_Interactable Get_Pickup(const FCk_Handle_WorldItem& InWorldItem) const
    {
        return InWorldItem.Get_Fragment(FMars_Fragment_WorldItem).Pickup;
    }

    private FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_WorldItem& InWorldItem) const
    {
        return Get_Pickup(InWorldItem).Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    // Invalid while the world item is not scene-node attached.
    private FCk_Handle_Transform Get_Parent(const FCk_Handle_WorldItem& InWorldItem) const
    {
        auto Node = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }
}
