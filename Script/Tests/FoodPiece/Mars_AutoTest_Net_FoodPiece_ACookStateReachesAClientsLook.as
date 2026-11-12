// The server sets a cook state (a 0.8 sear on +Z, a 0.5 oil coat) on its whole meat slab once it rests, and a different one
// 3 s later. The client's copy, bound to OnCookStateChanged from becoming a FoodPiece, wears the first before the second is
// written: its cook state is the first, OnCookStateChanged was raised once, its cook serial is 1 and its display shows an
// oil coat. After the second write it was raised exactly once more and wears the second.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_ACookStateReachesAClientsLook
class UCk_AutoTest_Net_FoodPiece_ACookStateReachesAClientsLook : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 161000.0;
    // The gap between the two writes: the client must wear the first inside it.
    private const float32 k_WriteGapSeconds = 3.0f;
    private const float32 k_ServerWatchSeconds = 4.0f;

    private FCk_Handle_FoodPiece _Piece;
    private int32 _Raised = 0;
    private int32 _RaisedAtFirst = 0;
    private int32 _SerialAtFirst = 0;
    private float32 _ShownAtFirst = 0.0f;

    private FMars_FoodPiece_CookState Get_First()
    {
        return Make_CookState(0.8f, 0.5f);
    }

    private FMars_FoodPiece_CookState Get_Second()
    {
        auto CookState = Make_CookState(0.9f, 0.25f);
        CookState.Sear[int32(EMars_FoodPiece_Face::NegX)] = 0.4f;
        return CookState;
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
        _Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Get_First()));
        WaitSeconds(k_WriteGapSeconds, n"OnServerWriteSecond");
    }

    UFUNCTION()
    private void OnServerWriteSecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Piece.Get_CookSerial(), 1, "the server's ledger carries one cook state");
        _Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(Get_Second()));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Piece.Get_CookSerial(), 2, "the server's ledger carries two cook states");
        Assert_True(Get_IsCookStateEqual(_Piece.Get_CookState(), Get_Second()), "the server's piece wears the second cook state");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"serial={_Piece.Get_CookSerial()}");
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
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
        WaitUntil(n"Is_ClientFirstShown", n"OnClientFirstShown", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCookStateChanged(FCk_Handle_FoodPiece InPiece)
    {
        ++_Raised;
    }

    // The first cook state worn and shown, or the second already arrived (the first was not worn in time).
    UFUNCTION()
    private void Is_ClientFirstShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (_Piece.Get_CookSerial() >= 2)
        {
            Result.Set(true);
            return;
        }

        const auto Shown = Get_ShownOilCoat(_Piece);
        Result.Set(Get_IsCookStateEqual(_Piece.Get_CookState(), Get_First()) && Shown.IsSet() && Shown.GetValue() > 0.0f);
    }

    UFUNCTION()
    private void OnClientFirstShown(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _RaisedAtFirst = _Raised;
        _SerialAtFirst = _Piece.Get_CookSerial();
        const auto Shown = Get_ShownOilCoat(_Piece);
        _ShownAtFirst = Shown.IsSet() ? Shown.GetValue() : -1.0f;

        Assert_Equals_Int(_SerialAtFirst, 1, "the client wears the first cook state before the second is written");
        Assert_True(Get_IsCookStateEqual(_Piece.Get_CookState(), Get_First()), "the client's cook state is the first");
        Assert_Equals_Int(_RaisedAtFirst, 1, "OnCookStateChanged was raised once for the first");
        Assert_True(_ShownAtFirst > 0.0f, f"the client's display shows an oil coat [{_ShownAtFirst}]");
        WaitUntil(n"Is_ClientSecondWorn", n"OnClientSecondWorn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientSecondWorn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Piece.Get_CookSerial() >= 2 && Get_IsCookStateEqual(_Piece.Get_CookState(), Get_Second()));
    }

    UFUNCTION()
    private void OnClientSecondWorn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Raised, _RaisedAtFirst + 1, "OnCookStateChanged was raised exactly once more for the second");
        Assert_Equals_Int(_Piece.Get_CookSerial(), 2, "the client's cook serial is 2");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        const auto Shown = Get_ShownOilCoat(_Piece);
        const auto ShownNow = Shown.IsSet() ? Shown.GetValue() : -1.0f;
        Log_Result(f"raisedAtFirst={_RaisedAtFirst} serialAtFirst={_SerialAtFirst} oilShownAtFirst={_ShownAtFirst} raised={_Raised} serial={_Piece.Get_CookSerial()} oilShownNow={ShownNow}");
        FinishSuccess();
    }
}
