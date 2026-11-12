// The client asks its Ready copy of a resting whole meat slab for a cook state with every sear at 1 and stamps the test's
// subject as its holder. After 1.5 s its copy has no Jolt body, reads no replicated holder and a cook serial of 0. The
// server, which gave its slab a body, still has it raw with a cook serial of 0 and no replicated holder, then cuts it; the
// client's copies of the two halves have no Jolt body either.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheClientWroteNoLedger
class UCk_AutoTest_Net_FoodPiece_TheClientWroteNoLedger : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 166000.0;
    private const float32 k_ClientSettleSeconds = 1.5f;
    // Long enough for the client's writes to have reached the server, had anything crossed.
    private const float32 k_ServerWatchSeconds = 4.0f;

    private FCk_Handle_FoodPiece _Piece;
    private bool _HadBody = false;
    private bool _ClientBody = false;
    private bool _ClientHolder = false;
    private int32 _ClientSerial = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientFoodReady", n"OnClientFoodReady", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
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
        _Piece = _Rock.As_FoodPiece();
        _HadBody = _Rock.Is_JoltBody();
        Publish_PieceReport(Get_PieceReport());
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_HadBody, "the server's whole food has a Jolt body");
        Assert_True(Get_IsCookStateZero(_Piece.Get_CookState()), "the server's slab is still raw");
        Assert_Equals_Int(_Piece.Get_CookSerial(), 0, "the server's cook serial is 0");
        Assert_True(ck::Is_NOT_Valid(_Piece.TryGet_ReplicatedHolder()), "the server's ledger names no holder");
        Log_Result(f"body={_HadBody} raw={Get_IsCookStateZero(_Piece.Get_CookState())} serial={_Piece.Get_CookSerial()} holder={ck::IsValid(_Piece.TryGet_ReplicatedHolder())}");
        Cut(_Piece, Make_CentrePlane());
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
        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut), 1, "the server's cut resolved Cut");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        WaitSeconds(4.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientFoodReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Food = Find_FoodPieceNear(_FloorTop);
        FCk_Handle Entity = Food;
        Result.Set(ck::IsValid(Food) && Get_IsFoodReady(Entity) && Get_PieceReport().Serial >= 1);
    }

    UFUNCTION()
    private void OnClientFoodReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = Find_FoodPieceNear(_FloorTop);

        auto Seared = FMars_FoodPiece_CookState();
        for (int32 Index = 0; Index < Seared.Sear.Num(); ++Index)
        { Seared.Sear[Index] = 1.0f; }

        _Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Seared));
        utils_foodpiece::Stamp_Holder(_Piece, Get_SubjectEntity());
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Entity = _Piece;
        _ClientBody = Entity.Is_JoltBody();
        _ClientHolder = ck::IsValid(_Piece.TryGet_ReplicatedHolder());
        _ClientSerial = _Piece.Get_CookSerial();
        Assert_False(_ClientBody, "the client's copy of the whole food has no Jolt body");
        Assert_False(_ClientHolder, "the client reads no replicated holder");
        Assert_Equals_Int(_ClientSerial, 0, "the client's cook serial is 0");
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
        auto Bodies = 0;
        for (const auto& Piece : Get_PieceEntitiesNear(_FloorTop))
        {
            if (Piece.Is_JoltBody())
            { ++Bodies; }
        }

        Assert_Equals_Int(Bodies, 0, "the client's copies of the halves have no Jolt body");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"body={_ClientBody} holder={_ClientHolder} serial={_ClientSerial} halfBodies={Bodies}");
        End_Client();
    }
}
