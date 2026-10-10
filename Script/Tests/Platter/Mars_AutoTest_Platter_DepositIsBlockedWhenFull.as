// A small platter that takes one piece, here only (the prep tray item at capacity 1).
asset Mars_ItemDef_AutoTest_PlatterOfOne of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Platter of one"));

    _ItemTraits.Add(mars_items::Make_PlatterPresentation(this, FVector::OneVector, FVector(12.0, 0.0, -14.0)));
    _ItemTraits.Add(Cast<UMars_ItemTrait_HandsOnly>(NewObject(this, UMars_ItemTrait_HandsOnly)));

    auto Platter = Cast<UMars_ItemTrait_Platter>(NewObject(this, UMars_ItemTrait_Platter));
    Platter.Platter = FMars_Platter_Spec(1, FMars_Platter_Bounds(FVector2D(9.15, 11.15), 40.0f, 25.0f));
    _ItemTraits.Add(Platter);
}

// A full platter refuses a deposit before it is tried: a capacity-1 platter on a floor holds one box piece; the carrier
// holds the mushroom slice's food item and focuses the platter: the prompt reads "Platter full" in the blocked colour and
// the platter's Use target is disabled. Isolated origin (22000, -19000, -30000).
class UMars_AutoTest_Platter_DepositIsBlockedWhenFull : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(22000.0, -19000.0, -30000.0);
    private const FVector k_PlatterOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);

    // Under construction until each is a WorldItem whose holder holds its item.
    private FCk_Handle _PlatterEntity;
    private FCk_Handle _FoodEntity;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_WorldItem _PlatterItem;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_FoodPiece _Box;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();

        auto Owner = InHandle;
        Spawn_Floor(Owner, k_Origin + k_PlatterOffset);
        _PlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            Mars_ItemDef_AutoTest_PlatterOfOne));
        _Box = Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset + FVector(0.0, 0.0, 60.0)));

        Spawn_Floor(Owner, k_Origin + k_FoodOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MushroomSlice());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the platter and the food item are constructed and the box is Ready", n"Check_Constructed", 0, 10.0f);
        Add_Step("load the box onto the platter of one", n"Step_LoadBox");
        Add_Step_WaitUntil("the box landed: the platter is full", n"Check_Full", 0, 5.0f);
        Add_Step("the carrier focuses the food's pickup", n"Step_FocusFood");
        Add_Step_WaitFrames("the food's target enters Focused", 3);
        Add_Step("the carrier picks the food up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the food is Held", n"Check_FoodHeld", 0, 5.0f);
        Add_Step("the carrier unfocuses the food and focuses the platter", n"Step_FocusPlatter");
        Add_Step_WaitFrames("the platter's target enters Focused and its prompt refreshes", 3);
        Add_Step("the prompt reads Platter full and the target is disabled", n"Step_AssertBlocked");
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

    // The FoodPiece rig's box fixture (a CPU-readable 1000 cm3 cube) with no kind: Transform, RuntimeMesh and FoodPiece on a
    // new entity under the world's transient entity, tracked for cleanup.
    private FCk_Handle_FoodPiece Build_Box(FTransform InWorld)
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
        const auto PlatterReady = ck::IsValid(_PlatterEntity) && _PlatterEntity.Is_Platter()
            && ck::IsValid(_PlatterEntity.As_WorldItem().Get_HeldItem());
        const auto FoodReady = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem()
            && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem());
        const auto BoxReady = _Box.Get_Status() == EMars_FoodPiece_Status::Ready;
        if (PlatterReady && FoodReady && ck::Is_NOT_Valid(_Platter))
        {
            _Platter = _PlatterEntity.As_Platter();
            _PlatterItem = _PlatterEntity.As_WorldItem();
            _Food = _FoodEntity.As_WorldItem();
        }

        auto Res = OutResult;
        Res.Set(PlatterReady && FoodReady && BoxReady);
    }

    UFUNCTION()
    private void Step_LoadBox(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platter.Get_Capacity(), 1, "the platter takes one piece");
        _Platter.Request_Load(FMars_Request_Platter_Load(_Box));
    }

    UFUNCTION()
    private void Check_Full(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 1 && _Platter.Get_IsFull());
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
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::Held);
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
    private void Step_AssertBlocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = Get_UseTarget(_PlatterItem);
        const auto Prompt = Target.As_InteractPrompt();
        Assert_Equals_String(Prompt.Get_PromptText().ToString(), "Platter full", "the prompt says the platter is full");
        Assert_True(Prompt.Get_PromptTextColor().Equals(constants_ui_colors::k_PromptText_Blocked), "in the blocked colour");
        Assert_True(utils_interact_target::Get_Enabled(Target) == ECk_EnableDisable::Disable, "the platter's Use target is disabled");
        Assert_True(Get_Pickup(_PlatterItem).Get_EnableDisable() == ECk_EnableDisable::Enable,
            "the platter's pickup itself stays enabled (the prompt shows why nothing happens)");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::Held, "the food stays in the hands");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the platter still holds only the box");
    }

    private FCk_Handle_Interactable Get_Pickup(const FCk_Handle_WorldItem& InWorldItem) const
    {
        return InWorldItem.Get_Fragment(FMars_Fragment_WorldItem).Pickup;
    }

    private FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_WorldItem& InWorldItem) const
    {
        return Get_Pickup(InWorldItem).Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }
}
