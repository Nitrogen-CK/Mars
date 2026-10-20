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

// A full platter refuses a deposit, and a press on it does nothing. A capacity-1 platter on a floor holds one box piece;
// the carrier holds the mushroom slice's food item and focuses the platter: once the prompt has followed the held food it
// reads "Platter full" in the blocked colour and the platter's Use target is disabled. The carrier then starts an
// interaction on that disabled target, as a press on a stale best target would: the framework refuses it (no interaction
// begins), the food stays in the hands and the platter's books are unchanged. Isolated origin (22000, -19000, -30000).
class UMars_AutoTest_Platter_DepositIsBlockedWhenFull : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(22000.0, -19000.0, -30000.0);
    private const FVector k_PlatterOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);
    // Item constructions, physics settles and mount commits outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    // Under construction until each is a WorldItem whose holder holds its item.
    private FCk_Handle _PlatterEntity;
    private FCk_Handle _FoodEntity;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_WorldItem _PlatterItem;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_FoodPiece _Box;

    // What the carrier held, and the platter's books, when it pressed on the disabled platter.
    private FCk_Handle_Item _HeldBeforePress;
    private int32 _PlatterHeldBeforePress = 0;
    private int32 _PlatterPendingBeforePress = 0;
    // Every interaction the platter's Use target began since the press.
    private int32 _InteractionsSincePress = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        auto Owner = InHandle;
        Spawn_FloorSlab(Owner, k_Origin + k_PlatterOffset);
        _PlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            Mars_ItemDef_AutoTest_PlatterOfOne));
        _Box = Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset + FVector(0.0, 0.0, 60.0)));

        Spawn_FloorSlab(Owner, k_Origin + k_FoodOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MushroomSlice());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the platter and the food item are constructed and the box is Ready", n"Check_Constructed", k_SlowPolls, 0);
        Add_Step("load the box onto the platter of one", n"Step_LoadBox");
        Add_Step_WaitUntil("the box landed: the platter is full", n"Check_Full", k_SlowPolls, 0);
        Add_Step("the carrier focuses the food's pickup", n"Step_FocusFood");
        Add_Step_WaitUntil("the food's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier picks the food up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the food is Held", n"Check_FoodHeld", k_SlowPolls, 0);
        Add_Step("the carrier unfocuses the food and focuses the platter", n"Step_FocusPlatter");
        Add_Step_WaitUntil("the platter's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step_WaitUntil("the platter's prompt leaves its placeholder for the held food", n"Check_PlatterPromptWritten", 0, 0);
        Add_Step("the prompt reads Platter full and the target is disabled", n"Step_AssertBlocked");
        Add_Step("the carrier starts an interaction on the platter's disabled target, as a stale best target would", n"Step_PressTheDisabledPlatter");
        Add_Step_WaitSeconds("an interaction the press began would show here", 0.25f);
        Add_Step("the framework refused the press: the food stays in the hands and the platter's books are unchanged", n"Step_AssertPressRefused");
        Run_Steps(InHandle);
    }

    // The cooking fixture's box with no kind, tracked for cleanup.
    private FCk_Handle_FoodPiece Build_Box(FTransform InWorld)
    {
        const auto Box = Get_CookingFixture().Build_Box(InWorld, FGameplayTag(), 0.8);
        Track_ForCleanup(Box);
        return Box;
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
        Await_FocusOf(Pickup);
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
        Await_FocusOf(PlatterPickup);
    }

    // The platter's prompt left the world item's placeholder ("Pick up <item>", which a focuser with no food also gets): the
    // platter's assembly wrote what the food in the focuser's hands can do there.
    UFUNCTION()
    private void Check_PlatterPromptWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto PromptText = Get_UseTarget(_PlatterItem).As_InteractPrompt().Get_PromptText().ToString();
        auto Res = OutResult;
        Res.Set(PromptText.StartsWith("Pick up") == false);
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

    UFUNCTION()
    private void Step_PressTheDisabledPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = Get_UseTarget(_PlatterItem);
        Assert_True(utils_interact_target::Get_Enabled(Target) == ECk_EnableDisable::Disable, "the platter's Use target is disabled before the press");

        _HeldBeforePress = _HeldItem.Get_CurrentItem();
        Assert_True(ck::IsValid(_HeldBeforePress) && _Hotbar.Get_ItemAt(0) == _HeldBeforePress, "the carrier holds the food from its bag slot before the press");
        _PlatterHeldBeforePress = _Platter.Get_HeldCount();
        _PlatterPendingBeforePress = _Platter.Get_PendingCount();

        Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnPlatterTargetNewInteraction"));
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertPressRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = Get_UseTarget(_PlatterItem);
        Assert_Equals_Int(_InteractionsSincePress, 0, "the platter's disabled target began no interaction");
        Assert_True(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(Target, _Carrier)), "the carrier has no interaction on the platter's target");

        Assert_True(_HeldItem.Get_CurrentItem() == _HeldBeforePress, "the carrier still holds the food");
        Assert_True(_Hotbar.Get_ItemAt(0) == _HeldBeforePress, "the bag slot still holds the food");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::Held, "the food is still Held");

        Assert_Equals_Int(_Platter.Get_HeldCount(), _PlatterHeldBeforePress, "the platter holds what it held before the press");
        Assert_Equals_Int(_Platter.Get_PendingCount(), _PlatterPendingBeforePress, "nothing waits to drop on the platter");
        Assert_True(_Platter.Get_Held().Contains(_Box), "the platter still holds only the box");
        Assert_True(ck::Is_NOT_Valid(_FoodEntity.As_FoodPiece().TryGet_Platter()), "the food's joint is on no platter's books");
    }

    UFUNCTION()
    private void OnPlatterTargetNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        ++_InteractionsSincePress;
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
