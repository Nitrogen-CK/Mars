// The server stows a Persistent food body lying beside the pack into cargo slot 0. On the client the food's own body ends
// Carried on that slot at AttachPoint.Mars.Dock, the only mount change it records after it was seen lying in the world is
// Carried (no World commit in transit), the client's slot spawns no cargo visual for it, and nobody ensures.
// Surface: Ck.Backpack.Net.AS_CargoSlot_AStowedFoodRidesTheSlotOnTheClient
class UCk_AutoTest_Net_CargoSlot_AStowedFoodRidesTheSlotOnTheClient : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(53000.0, 0.0, 5000.0);

    private FCk_Handle_WorldItem _FoodBody;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetBackpack(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_FoodSettled", n"OnClientFoodSettled", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPack();
        Spawn_ServerBeside(mars_items::Food_MeatSlab());
        WaitUntil(n"Is_FoodSettled", n"OnServerFoodSettled", k_SlowPolls);
    }

    // The client has found the food lying in the world before it moves.
    UFUNCTION()
    private void OnServerFoodSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientCatchUpSeconds, n"OnServerCaughtUp");
    }

    UFUNCTION()
    private void OnServerCaughtUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_Item));
        WaitUntil(n"Is_FoodOnSlot", n"OnServerFoodOnSlot", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFoodOnSlot(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFoodSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Record_MountChanges(_FoodBody);
        WaitUntil(n"Is_FoodOnSlot", n"OnClientFoodArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFoodArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(5, n"OnClientFoodOnSlot");
    }

    UFUNCTION()
    private void OnClientFoodOnSlot(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Sequence = Describe_MountChanges();
        const auto OnlyCarried = _MountChanges.Num() == 1 && _MountChanges[0] == EMars_WorldItem_Mount::Carried;
        const auto NoVisual = ck::Is_NOT_Valid(_Slot0.Get_Visual());
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[CargoSlotNetTest] stowed food rides the slot mounts=[{Sequence}] noVisual={NoVisual} newEnsures={NewEnsures}");
        Assert_True(OnlyCarried, f"the client's food body recorded exactly [Carried] (got [{Sequence}])");
        Assert_True(NoVisual, "the client's slot spawned no cargo visual for the food");
        Assert_True(NewEnsures == 0, f"the client saw no ensure (got {NewEnsures})");
        FinishSuccess();
    }

    // The pack is ready and the food's body is linked, lying in the world and settled on this machine.
    UFUNCTION()
    private void Is_FoodSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsPackReady() == false)
        { Result.Set(false); return; }

        if (ck::Is_NOT_Valid(_FoodBody))
        { _FoodBody = Find_FoodBody(); }

        const auto Ready = ck::IsValid(_FoodBody) && _FoodBody.Get_IsLinked() && ck::IsValid(_FoodBody.Get_HeldItem())
            && _FoodBody.Get_Mount() == EMars_WorldItem_Mount::World && _FoodBody.Get_IsSettled();
        if (Ready)
        { _Item = _FoodBody.Get_HeldItem(); }

        Result.Set(Ready);
    }

    // The food's body is Carried by this machine's cargo slot 0 at its dock point, settled, and the slot holds the food.
    UFUNCTION()
    private void Is_FoodOnSlot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const FCk_Handle SlotEntity = _Slot0;
        Result.Set(ck::IsValid(_FoodBody) && _Slot0.Get_Item() == _Item
            && _FoodBody.Get_Mount() == EMars_WorldItem_Mount::Carried && _FoodBody.Get_Carrier() == SlotEntity
            && _FoodBody.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Dock && _FoodBody.Get_IsSettled());
    }

    private FCk_Handle_WorldItem Find_FoodBody()
    {
        const auto Near = _FloorTop + k_SideFromFloor;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World || Candidate.Is_Backpack())
            { continue; }

            const auto Location = Get_RootLocation(Candidate);
            if (FVector2D(Location.X - Near.X, Location.Y - Near.Y).Size() < 150.0)
            { return WorldItem; }
        }

        return FCk_Handle_WorldItem();
    }
}
