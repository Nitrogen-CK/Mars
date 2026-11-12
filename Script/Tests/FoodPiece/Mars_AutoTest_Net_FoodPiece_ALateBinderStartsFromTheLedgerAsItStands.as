// The server writes two cook states into its whole meat slab in consecutive frames as soon as its piece is Ready. The
// client binds OnCookStateChanged when its copy becomes a FoodPiece, whatever has arrived by then: it is raised at most
// twice in all, the copy ends wearing the second write, and its display, once Ready, shows the second write's oil coat.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_FoodPiece_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 162000.0;
    private const float32 k_ServerWatchSeconds = 6.0f;
    // After the copy wears the second write: long enough for a late duplicate to be raised, had one been coming.
    private const float32 k_ClientSettleSeconds = 1.0f;
    private const float32 k_OilTolerance = 0.0001f;

    private FCk_Handle_FoodPiece _Piece;
    private int32 _Raised = 0;
    private float32 _Shown = -1.0f;

    private FMars_FoodPiece_CookState Get_First()
    {
        return Make_CookState(0.3f, 0.2f);
    }

    private FMars_FoodPiece_CookState Get_Second()
    {
        return Make_CookState(0.7f, 0.6f);
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientComposed", n"OnClientComposed", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_ServerSlabReady", n"OnServerSlabReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_Rock));
    }

    UFUNCTION()
    private void OnServerSlabReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = _Rock.As_FoodPiece();
        _Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Get_First()));
        WaitFrames(1, n"OnServerWriteSecond");
    }

    UFUNCTION()
    private void OnServerWriteSecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Get_Second()));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCookStateEqual(_Piece.Get_CookState(), Get_Second()), "the server's piece wears the second write");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"serial={_Piece.Get_CookSerial()}");
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(Find_FoodPieceNear(_FloorTop)));
    }

    UFUNCTION()
    private void OnClientComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = Find_FoodPieceNear(_FloorTop);
        _Piece.BindTo_OnCookStateChanged(FMars_Delegate_FoodPiece_OnCookStateChanged(this, n"OnClientCookStateChanged"));
        WaitUntil(n"Is_ClientSecondShown", n"OnClientSecondShown", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCookStateChanged(FCk_Handle_FoodPiece InPiece)
    {
        ++_Raised;
    }

    UFUNCTION()
    private void Is_ClientSecondShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Shown = Get_ShownOilCoat(_Piece);
        Result.Set(Get_IsCookStateEqual(_Piece.Get_CookState(), Get_Second()) && Shown.IsSet()
            && Math::Abs(Shown.GetValue() - Get_Second().OilCoat) <= k_OilTolerance);
    }

    UFUNCTION()
    private void OnClientSecondShown(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Shown = Get_ShownOilCoat(_Piece).GetValue();
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Raised <= 2, f"OnCookStateChanged was raised at most twice (raised {_Raised})");
        Assert_True(Get_IsCookStateEqual(_Piece.Get_CookState(), Get_Second()), "the client's copy wears the second write");
        Assert_Equals_Float(_Shown, Get_Second().OilCoat, k_OilTolerance, "the client's display shows the second write's oil coat");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"raised={_Raised} serial={_Piece.Get_CookSerial()} oilShown={_Shown}");
        End_Client();
    }
}
