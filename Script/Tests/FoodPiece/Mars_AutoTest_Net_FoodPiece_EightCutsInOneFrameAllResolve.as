// The server spawns eight whole mushrooms 60 cm apart and, once all are Ready, cuts every one through its centre in one
// frame. All eight resolve Cut and sixteen Ready halves stand where they were; the server logs how many frames that took.
// The client ends up with sixteen piece scripts and no whole food near the test's X.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_EightCutsInOneFrameAllResolve
class UCk_AutoTest_Net_FoodPiece_EightCutsInOneFrameAllResolve : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 155000.0;
    private const int32 k_FoodCount = 8;
    private const float64 k_SpacingCm = 60.0;

    private TArray<FCk_Handle> _Foods;
    private int32 _FramesToResolve = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientSixteenThere", n"OnClientSixteenThere", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        for (int32 Index = 0; Index < k_FoodCount; ++Index)
        {
            const auto Offset = FVector((float64(Index) - float64(k_FoodCount - 1) * 0.5) * k_SpacingCm, 0.0, 5.0);
            _Foods.Add(Spawn_ServerFood(mars_items::Food_Mushroom(), _FloorTop + Offset));
        }

        WaitUntil(n"Is_ServerFoodsReady", n"OnServerFoodsReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFoodsReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = true;
        for (const auto& Food : _Foods)
        { AllReady = AllReady && Get_IsFoodReady(Food); }

        auto Result = OutResult;
        Result.Set(AllReady);
    }

    UFUNCTION()
    private void OnServerFoodsReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        for (const auto& Food : _Foods)
        { Cut(Food.As_FoodPiece(), Make_CentrePlane()); }

        WaitUntil(n"Is_ServerAllResolved", n"OnServerAllResolved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAllResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_FramesToResolve;
        auto Result = OutResult;
        Result.Set(_Cuts.Num() >= k_FoodCount);
    }

    UFUNCTION()
    private void OnServerAllResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, n"OnServerFrameAfterResolved");
    }

    UFUNCTION()
    private void OnServerFrameAfterResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto ReadyHalves = 0;
        for (const auto& Result : _Cuts)
        {
            if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
            { continue; }

            ReadyHalves += Result.Positive.Get_Status() == EMars_FoodPiece_Status::Ready ? 1 : 0;
            ReadyHalves += Result.Negative.Get_Status() == EMars_FoodPiece_Status::Ready ? 1 : 0;
        }

        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut), k_FoodCount, "all eight cuts resolved Cut");
        Assert_Equals_Int(ReadyHalves, k_FoodCount * 2, "sixteen Ready halves");
        Assert_Equals_Int(Get_PieceEntitiesNear(_FloorTop).Num(), k_FoodCount * 2, "sixteen piece scripts near the test's X");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"cuts={Get_CutCount(EMars_FoodPiece_CutOutcome::Cut)} readyHalves={ReadyHalves} framesFromCutsToLastResolution={_FramesToResolve}");
        WaitSeconds(4.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientSixteenThere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_PieceEntitiesNear(_FloorTop).Num() == k_FoodCount * 2 && Get_WorldItemCountNear(_FloorTop) == 0);
    }

    UFUNCTION()
    private void OnClientSixteenThere(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_PieceEntitiesNear(_FloorTop).Num(), k_FoodCount * 2, "sixteen piece scripts on the client");
        Assert_Equals_Int(Get_WorldItemCountNear(_FloorTop), 0, "no whole food left on the client");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Get_PieceEntitiesNear(_FloorTop).Num()} worldItems={Get_WorldItemCountNear(_FloorTop)}");
        FinishSuccess();
    }
}
