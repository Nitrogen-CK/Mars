// A World-mode food item the server spawns through the world-item spawn funnel reaches the client: the client's copy
// finishes its own construction (the joint is imported there from the definition), its holder holds the one item, it has
// no body (the server simulates it), and its root comes to rest within 1 cm of where the server's did.
// Surface: Ck.WorldItem.Net.AS_WorldItem_FoodItemReachesTheClient
class UCk_AutoTest_Net_WorldItem_FoodItemReachesTheClient : UMars_AutoTestRig_NetWorldItem
{
    private const FVector k_FloorTop = FVector(23000.0, 0.0, 5000.0);
    private const float64 k_RestToleranceCm = 1.0;

    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Add_Report();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientFoodHeldAndReported", n"OnClientFoodReported", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_FloorTop + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        _Rock = utils_world_item::Request_SpawnWorldEntity(Owner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_Rock);
        WaitUntil(n"Is_ServerFoodHeldAndStill", n"OnServerFoodStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFoodHeldAndStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Still = Tick_RockStill();
        auto Result = OutResult;
        Result.Set(Still && Get_HolderCount(_Rock.As_WorldItem()) == 1);
    }

    UFUNCTION()
    private void OnServerFoodStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(utils_entity_replication_driver::Has(_Rock), "the server's food item has a replication driver");
        Assert_True(ck::IsValid(_Rock.As_WorldItem().Get_Body()), "the server's food item has its body");
        Write_Report(Get_RootLocation(_Rock));
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // The client's food item is constructed (a WorldItem only once its joint is ready), holds a valid item, the server has
    // reported its rest, and the client's root has reached it.
    UFUNCTION()
    private void Is_ClientFoodHeldAndReported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_WorldItem) || ck::Is_NOT_Valid(_WorldItem.Get_HeldItem()) || Get_Report().Serial < 1)
        {
            Result.Set(false);
            return;
        }

        Result.Set(Get_RootLocation(_WorldItem).Equals(Get_Report().RestLocation, k_RestToleranceCm));
    }

    UFUNCTION()
    private void OnClientFoodReported(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_WorldItem), "the client's food item has no authority");
        Assert_True(_WorldItem.Is_FoodPiece(), "the client's food item composed its joint");
        Assert_Equals_Int(Get_HolderCount(_WorldItem), 1, "the client's holder holds the one item");
        Assert_True(ck::Is_NOT_Valid(_WorldItem.Get_Body()), "the client's food item has no body");
        Assert_True(ck::Is_NOT_Valid(_WorldItem.As_JoltBody(ECk_SanityCheck::UnChecked)), "the client's root is no Jolt body");
        FinishSuccess();
    }
}
