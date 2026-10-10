// Food goes onto a platter by hand and comes back off by hand. The carrier (with gloves) picks the meat slab's food item up
// (its own pickup) into its bag slot, then interacts with a large platter lying on a floor: the platter's prompt offers
// "Place Meat slab on platter", and its interaction (UMars_SmTask_PlaceHeldFood) has the gloves carry the slab over the
// platter (a Place reach: Reach, then Grip) and only at the Grip releases the food (its world item back in the world, the
// item back in its holder) and loads the joint: the platter drops it, it settles and OnLoaded fires within 3 s with the
// joint a scene-node child of the root. Then the slab's own pickup takes it back: the Mount processor detaches it from the
// root, the platter's Reconcile broadcasts OnUnloaded and empties the ledger, and the slab is Held again. Isolated origin
// (22000, -17000, -30000).
class UMars_AutoTest_Platter_DepositPlacesTheHeldFoodAndPickupTakesItBack : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(22000.0, -17000.0, -30000.0);
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

    // The gloves' phases when the food left the hands, and whether it was still Held the frame after the interaction began.
    private TArray<EMars_FPHands_Phase> _PhasesAtRelease;
    private bool _ReleasedAtRelease = false;
    private EMars_WorldItem_Mount _MountAfterDepositStart = EMars_WorldItem_Mount::World;

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
        Add_Step_WaitFrames("the platter's target enters Focused and its prompt refreshes", 3);
        Add_Step("the platter offers to place the food", n"Step_AssertDepositPrompt");
        Add_Step("the carrier interacts with the platter", n"Step_Deposit");
        Add_Step_WaitFrames("the interaction has begun", 1);
        Add_Step("the food is still in the hands: the place waits for the gloves", n"Step_RecordAfterDepositStart");
        Add_Step_WaitUntil("the food is released into the world", n"Check_FoodReleased", 0, 3.0f);
        Add_Step("the food left the hands at the gloves' Grip, after their Reach", n"Step_AssertReleasedAtTheGrip");
        Add_Step_WaitUntil("the platter loaded the joint", n"Check_Loaded", 0, 3.0f);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("the joint is on the platter and the hands are empty", n"Step_AssertOnThePlatter");
        Add_Step("the carrier unfocuses the platter", n"Step_UnfocusPlatter");
        Add_Step_WaitFrames("the platter's target leaves Focused", 2);
        Add_Step("the carrier focuses the food's pickup again", n"Step_FocusFood");
        Add_Step_WaitFrames("the food's target enters Focused", 3);
        Add_Step("the carrier takes the food off the platter", n"Step_PickUpFood");
        Add_Step_WaitUntil("the food is Held again and the platter unloaded it", n"Check_TakenBack", 0, 5.0f);
        Add_Step("the platter is empty and the joint rides the hand", n"Step_AssertTakenBack");
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
            _Food.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnFoodMountChanged"));
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
    private void Step_AssertDepositPrompt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = Get_UseTarget(_PlatterItem);
        const auto Prompt = Target.As_InteractPrompt();
        Assert_Equals_String(Prompt.Get_PromptText().ToString(), "Place Meat slab on platter", "the platter offers to place the held food");
        Assert_True(utils_interact_target::Get_Enabled(Target) == ECk_EnableDisable::Enable, "the platter's target is enabled");
        Assert_True(Get_Pickup(_PlatterItem).Get_EnableDisable() == ECk_EnableDisable::Enable,
            "the platter's pickup stays enabled for a focuser holding food");
    }

    UFUNCTION()
    private void Step_Deposit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = Get_UseTarget(_PlatterItem);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_RecordAfterDepositStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _MountAfterDepositStart = _Food.Get_Mount();
        Assert_True(_MountAfterDepositStart == EMars_WorldItem_Mount::Held, "the food is still Held the frame after the interaction began");
        Assert_Equals_Int(_Loaded.Num(), 0, "nothing is loaded on enter");
    }

    UFUNCTION()
    private void Step_AssertReleasedAtTheGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ReleasedAtRelease, "the food's mount changed to World once");
        Assert_True(_PhasesAtRelease.Contains(EMars_FPHands_Phase::Reach), "the gloves reached before the food left them");
        Assert_True(_PhasesAtRelease.Num() > 0 && _PhasesAtRelease.Last() == EMars_FPHands_Phase::Grip,
            f"the food left the hands in the Grip phase ({_PhasesAtRelease.Num()} phase changes)");
    }

    UFUNCTION()
    private void OnFoodMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        if (InNew != EMars_WorldItem_Mount::World || _ReleasedAtRelease)
        { return; }

        _ReleasedAtRelease = true;
        _PhasesAtRelease = _HandPhases;
    }

    UFUNCTION()
    private void Check_FoodReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::World && _Food.Get_HeldItem() == _FoodItem);
    }

    UFUNCTION()
    private void Check_Loaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Loaded.Contains(_Joint));
    }

    UFUNCTION()
    private void Step_AssertOnThePlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle PlatterEntity = _Platter;
        Assert_True(Get_JointParent() == PlatterEntity.As_Transform(), "the joint is a scene-node child of the platter root");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "the platter holds one piece");
        Assert_True(_Platter.Get_Held().Contains(_Joint), "the held piece is the food's joint");
        Assert_True(_Joint.TryGet_Platter() == _Platter, "the joint's membership names the platter");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)), "the bag slot is empty");
        Assert_True(_Food.Get_HeldItem() == _FoodItem, "the food item is back in its holder");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::World, "the food's mount is World");
        Assert_Equals_Int(_Unloaded.Num(), 0, "nothing was unloaded yet");
    }

    UFUNCTION()
    private void Step_UnfocusPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto PlatterPickup = Get_Pickup(_PlatterItem);
        PlatterPickup.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Carrier));
    }

    UFUNCTION()
    private void Check_TakenBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::Held && Get_Parent(_Food) == _HandNode && _Unloaded.Contains(_Joint));
    }

    UFUNCTION()
    private void Step_AssertTakenBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Unloaded.Num(), 1, "the platter unloaded the joint once (its Reconcile)");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is empty");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint is off the platter's books");
        Assert_True(_Hotbar.Get_ItemAt(0) == _FoodItem, "the food is back in the bag slot");
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

    // Invalid while the joint is not scene-node attached.
    private FCk_Handle_Transform Get_JointParent() const
    {
        FCk_Handle Entity = _Joint;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }
}
