// Each machine records the held item of its copy of a whole meat slab before the server cuts it. Once the cut's halves are
// there, no world item is left near the test's X on either machine and the recorded item is gone or ending on both.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheSourcesItemEndsWithIt
class UCk_AutoTest_Net_FoodPiece_TheSourcesItemEndsWithIt : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 154000.0;
    // A client sees the whole food before the server cuts it.
    private const float32 k_BeforeCutSeconds = 1.5f;
    private const float32 k_AfterCutSeconds = 1.0f;

    private FCk_Handle_Item _Item;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientItemThere", n"OnClientItemThere", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private bool Get_IsItemEnding()
    {
        return ck::Is_NOT_Valid(_Item) || utils_entity_lifetime::Get_IsPendingDestroy(_Item, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_ServerSlabStill", n"OnServerSlabStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Tick_SlabReadyAndStill());
    }

    UFUNCTION()
    private void OnServerSlabStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Item = _Rock.As_WorldItem().Get_HeldItem();
        Assert_True(ck::IsValid(_Item), "the server's food holds its item before the cut");
        WaitSeconds(k_BeforeCutSeconds, n"OnServerCutDue");
    }

    UFUNCTION()
    private void OnServerCutDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
        WaitUntil(n"Is_ServerCutResolved", n"OnServerCutResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the cut resolved Cut (got {_Cuts[0].Outcome :n})");
        WaitSeconds(k_AfterCutSeconds, n"OnServerAfterCut");
    }

    UFUNCTION()
    private void OnServerAfterCut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_WorldItemCountNear(_FloorTop), 0, "no world item is left near the test's X on the server");
        Assert_True(Get_IsItemEnding(), "the server's item ended with its food");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"worldItems={Get_WorldItemCountNear(_FloorTop)} itemEnded={Get_IsItemEnding()}");
        WaitSeconds(3.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientItemThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto WorldItem = Find_WorldItemNear(_FloorTop);
        if (ck::IsValid(WorldItem))
        { _Item = WorldItem.Get_HeldItem(); }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_Item));
    }

    UFUNCTION()
    private void OnClientItemThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_PieceEntitiesNear(_FloorTop).Num(), 0, "the client recorded its item before the cut");
        WaitUntil(n"Is_ClientHalvesThere", n"OnClientHalvesThere", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHalvesThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_PieceEntitiesNear(_FloorTop).Num() == 2);
    }

    UFUNCTION()
    private void OnClientHalvesThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_AfterCutSeconds, n"OnClientAfterCut");
    }

    UFUNCTION()
    private void OnClientAfterCut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_WorldItemCountNear(_FloorTop), 0, "no world item is left near the test's X on the client");
        Assert_True(Get_IsItemEnding(), "the client's item ended with its food");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"worldItems={Get_WorldItemCountNear(_FloorTop)} itemEnded={Get_IsItemEnding()}");
        End_Client();
    }
}
