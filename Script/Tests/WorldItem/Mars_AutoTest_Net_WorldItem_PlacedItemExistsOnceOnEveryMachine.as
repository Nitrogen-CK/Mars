// A World-mode item the server spawns under the spawn owner exists once on the client: its holder holds the item there
// too, its body simulates on the server alone (the client's root has no Jolt body), and the client's root comes to rest
// within 1 cm of where the server's did.
// Surface: Ck.WorldItem.Net.AS_WorldItem_PlacedItemExistsOnceOnEveryMachine
class UCk_AutoTest_Net_WorldItem_PlacedItemExistsOnceOnEveryMachine : UMars_AutoTestRig_NetWorldItem
{
    private const FVector k_FloorTop = FVector(17000.0, 0.0, 5000.0);
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
            WaitUntil(n"Is_ClientRockHeldAndReported", n"OnClientRockReported", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerRock(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitUntil(n"Is_ServerRockHeldAndStill", n"OnServerRockStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRockHeldAndStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Still = Tick_RockStill();
        auto Result = OutResult;
        Result.Set(Still && Get_HolderCount(_Rock.As_WorldItem()) == 1);
    }

    UFUNCTION()
    private void OnServerRockStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(ck::IsValid(_Rock.As_WorldItem().Get_Body()), "the server's rock has its Jolt body");
        Write_Report(Get_RootLocation(_Rock));
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // The client's rock holds a valid item, the server has reported its rest, and the client's root has reached it.
    UFUNCTION()
    private void Is_ClientRockHeldAndReported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
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
    private void OnClientRockReported(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_WorldItem), "the client's rock has no authority");
        Assert_Equals_Int(Get_HolderCount(_WorldItem), 1, "the client's holder holds the one item");
        Assert_True(ck::Is_NOT_Valid(_WorldItem.Get_Body()), "the client's rock has no body");
        Assert_True(ck::Is_NOT_Valid(_WorldItem.As_JoltBody(ECk_SanityCheck::UnChecked)), "the client's root is no Jolt body");
        FinishSuccess();
    }
}
