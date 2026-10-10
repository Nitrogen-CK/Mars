// A meat slab's food item whose holder refuses its item back once it is linked (the seed is taken; every return is refused).
class UMars_AutoTestHelper_FoodItem_RefusingHolder : UMars_FoodItem_EntityScript
{
    protected FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic Get_HolderAcceptPolicy() const override
    {
        TSubclassOf<UMars_AutoTestHelper_HolderRefusesLinkedItems> PolicyClass = UMars_AutoTestHelper_HolderRefusesLinkedItems;
        return FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(PolicyClass.GetDefaultObject(), n"OnCanAccept");
    }
}

// A deposit whose release is refused keeps the food. The gloved carrier picks up a meat slab whose holder refuses its item
// back, then interacts with a large platter: the gloves carry the slab over the platter and, at their Grip, the deposit
// releases it - the release's transfer back into the holder is refused (OnReleaseRefused). The deposit fails before it asks
// the platter for anything: the slab is still Held, still on the carrier's Hand node, its item in the bag slot; the platter
// holds nothing and was never asked to load it; the interaction ends Failed. The rollback's warning and the release's
// ensure are expected (the actor below). Isolated origin (27600, -17000, -30000).
class UMars_AutoTest_Platter_ADepositWhoseReleaseIsRefusedKeepsTheFood : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(27600.0, -17000.0, -30000.0);
    private const FVector k_PlatterOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);

    private FCk_Handle _PlatterEntity;
    private FCk_Handle _FoodEntity;
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_WorldItem _PlatterItem;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_Item _FoodItem;
    private FCk_Handle_FoodPiece _Joint;

    private TArray<EMars_WorldItem_ReleaseRefusal> _ReleaseRefusals;
    private TArray<FCk_Handle_FoodPiece> _LoadAnswers;
    private TArray<ECk_SucceededFailed> _DepositResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();

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
        _FoodEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_AutoTestHelper_FoodItem_RefusingHolder, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the platter and the food item are constructed", n"Check_Constructed", 0, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step("the carrier focuses the food's pickup", n"Step_FocusFood");
        Add_Step_WaitUntil("the food's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier picks the food up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the food is Held and settled on the hand", n"Check_FoodHeldAndSettled", 0, 0);
        Add_Step("the carrier unfocuses the food and focuses the platter", n"Step_FocusPlatter");
        Add_Step_WaitUntil("the platter's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("watch the release and the platter; the carrier interacts with the platter", n"Step_WatchAndDeposit");
        Add_Step_WaitUntil("the deposit's interaction ends", n"Check_DepositEnded", 0, 0);
        Add_Step("the release was refused, the deposit failed and the food stayed in the hands", n"Step_AssertKept");
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
        }

        auto Res = OutResult;
        Res.Set(PlatterReady && FoodReady);
    }

    UFUNCTION()
    private void Step_FocusFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Food.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(Pickup);
    }

    UFUNCTION()
    private void Step_PickUpFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = Get_UseTarget(_Food);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_FoodHeldAndSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::Held && Get_Parent(_Food) == _HandNode && _Food.Get_IsSettled());
    }

    UFUNCTION()
    private void Step_FocusPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto FoodPickup = _Food.Get_Pickup();
        FoodPickup.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Carrier));

        auto PlatterPickup = _PlatterItem.Get_Pickup();
        PlatterPickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(PlatterPickup);
    }

    UFUNCTION()
    private void Step_WatchAndDeposit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Food.BindTo_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnReleaseRefused"));
        _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnLoaded"));
        _Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnLoadRefused"));

        auto Target = Get_UseTarget(_PlatterItem);
        Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnDepositFinished"));
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void OnReleaseRefused(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        _ReleaseRefusals.Add(InReason);
    }

    UFUNCTION()
    private void OnLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _LoadAnswers.Add(InPiece);
    }

    UFUNCTION()
    private void OnLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        _LoadAnswers.Add(InPiece);
    }

    UFUNCTION()
    private void OnDepositFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _DepositResults.Add(InResult);
    }

    UFUNCTION()
    private void Check_DepositEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_DepositResults.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ReleaseRefusals.Num() == 1 && _ReleaseRefusals[0] == EMars_WorldItem_ReleaseRefusal::TransferFailed,
            f"the release was refused once: its transfer back into the holder failed ({_ReleaseRefusals.Num()} refusal(s))");
        Assert_True(_DepositResults[0] == ECk_SucceededFailed::Failed, f"the deposit's interaction ended Failed (got {_DepositResults[0] :n})");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::Held && _Food.Get_Carrier() == _Carrier, "the food is still Held by the carrier");
        Assert_True(Get_Parent(_Food) == _HandNode, "the food is still on the carrier's Hand node");
        Assert_True(_Hotbar.Get_ItemAt(0) == _FoodItem, "its item is still in the bag slot");
        Assert_Equals_Int(_Food.Get_Holder().Get_NumItems(), 0, "its holder stayed empty");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter holds nothing");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint is on no platter's books");
        Assert_Equals_Int(_LoadAnswers.Num(), 0, "the platter was never asked to load it");
    }

    private FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_WorldItem& InWorldItem) const
    {
        return InWorldItem.Get_Pickup().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
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

// Hand-authored so CkInventory's rollback Warning for the refused return (the automation controller elevates Warnings to
// test errors) and the release's own ensure are expected rather than failures. Pinned to the item definition and the
// refusal reason, and to the release's message, so an unrelated refusal or ensure still fails the test.
class AMars_AutoTest_Platter_ADepositWhoseReleaseIsRefusedKeepsTheFood_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Platter_ADepositWhoseReleaseIsRefusedKeepsTheFood;
    default _TimeoutSeconds = 30.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Mars_ItemDef_Food_MeatSlab))] (Failed Rejected by Custom Acceptance Logic)");
        Out.Add("it stays mounted");
        return Out;
    }
}
