// A deposit whose food dies after its release landed fails LeftTheBooks instead of waiting forever. The gloved carrier picks
// up a meat slab and interacts with a large platter: at the gloves' Grip the deposit releases the slab, and the moment its
// world item settles World the test destroys the joint. The deposit then fails: the interaction ends Failed, the platter's
// pickup reports LeftTheBooks, the platter holds nothing and was never answered for it. Isolated origin
// (29200, -17000, -30000).
class UMars_AutoTest_Platter_PlaceHeldFoodFailsWhenThePieceDiesWhileLeaving : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(29200.0, -17000.0, -30000.0);
    private const FVector k_PlatterOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);
    // A poll budget, not a ceiling: the gloves reach, grip and let go, and the release lands, over seconds.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _PlatterEntity;
    private FCk_Handle _FoodEntity;
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_WorldItem _PlatterItem;
    private FCk_Handle_WorldItem _Food;

    private int32 _JointsDestroyed = 0;
    private TArray<FCk_Handle_FoodPiece> _LoadAnswers;
    private TArray<ECk_SucceededFailed> _DepositResults;
    private TArray<EMars_Interaction_FailReason> _FailReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();

        auto Owner = InHandle;
        Spawn_FloorSlab(Owner, k_Origin + k_PlatterOffset);
        _PlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            mars_items::Platter_Large()));

        Spawn_FloorSlab(Owner, k_Origin + k_FoodOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        _FoodEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the platter and the food item are constructed", n"Check_Constructed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step("the carrier focuses the food's pickup", n"Step_FocusFood");
        Add_Step_WaitUntil("the food's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier picks the food up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the food is Held and settled on the hand", n"Check_FoodHeldAndSettled", k_SlowPolls, 0);
        Add_Step("the carrier unfocuses the food and focuses the platter", n"Step_FocusPlatter");
        Add_Step_WaitUntil("the platter's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("watch the release and the platter; the carrier interacts with the platter", n"Step_WatchAndDeposit");
        Add_Step_WaitUntil("the release landed World and the joint was destroyed", n"Check_JointDestroyed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the deposit's interaction ends", n"Check_DepositEnded", k_SlowPolls, 0);
        Add_Step("the joint died after its release and the deposit failed LeftTheBooks", n"Step_AssertFailed");
        Run_Steps(InHandle);
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
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::Held && _Food.Get_IsSettled());
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
        _Food.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnFoodMountSettled"));
        _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnLoaded"));
        _Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnLoadRefused"));

        auto Pickup = _PlatterItem.Get_Pickup();
        Pickup.BindTo_OnInteractionFailed(FMars_Delegate_Interactable_OnInteractionFailed(this, n"OnDepositFailed"));

        auto Target = Get_UseTarget(_PlatterItem);
        Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnDepositFinished"));
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    // The release landed: the joint dies before the deposit can ask the platter for it.
    UFUNCTION()
    private void OnFoodMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        if (InMount != EMars_WorldItem_Mount::World || _JointsDestroyed > 0)
        { return; }

        ++_JointsDestroyed;
        utils_entity_lifetime::Request_DestroyEntity(_FoodEntity);
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
    private void OnDepositFailed(FCk_Handle_Interactable InInteractable, FMars_Interactable_Failure InFailure)
    {
        _FailReasons.Add(InFailure.Reason);
    }

    UFUNCTION()
    private void OnDepositFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _DepositResults.Add(InResult);
    }

    UFUNCTION()
    private void Check_JointDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_JointsDestroyed > 0);
    }

    UFUNCTION()
    private void Check_DepositEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_DepositResults.Num() > 0 && _FailReasons.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertFailed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_JointsDestroyed, 1, "the release landed World and the joint was destroyed then");
        Assert_True(_DepositResults[0] == ECk_SucceededFailed::Failed, f"the deposit's interaction ended Failed (got {_DepositResults[0] :n})");
        Assert_Equals_Int(_FailReasons.Num(), 1, "the platter's pickup reported one failed interaction");
        Assert_True(_FailReasons[0] == EMars_Interaction_FailReason::LeftTheBooks, f"it failed LeftTheBooks (got [{_FailReasons[0] :n}])");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter holds nothing");
        Assert_Equals_Int(_LoadAnswers.Num(), 0, "the platter was never answered for the dead joint");
    }

    private FCk_Handle_InteractTarget Get_UseTarget(const FCk_Handle_WorldItem& InWorldItem) const
    {
        return InWorldItem.Get_Pickup().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }
}
