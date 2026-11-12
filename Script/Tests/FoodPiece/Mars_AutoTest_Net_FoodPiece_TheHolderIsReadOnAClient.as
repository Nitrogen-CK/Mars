// The server stamps the test's subject as the holder of its resting whole meat slab, then clears it 3 s later. The client's
// copy reads its own copy of the subject through TryGet_ReplicatedHolder, then reads invalid within 3 s of the clear, and
// never had a holder fragment of its own.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheHolderIsReadOnAClient
class UCk_AutoTest_Net_FoodPiece_TheHolderIsReadOnAClient : UMars_AutoTestRig_NetFoodPiece
{
    private const float64 k_X = 163000.0;
    private const float32 k_HeldSeconds = 3.0f;
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const float64 k_ClearSeconds = 3.0;

    private FCk_Handle_FoodPiece _Piece;
    private bool _EverHadOwnHolder = false;
    private TOptional<float64> _ClearedAt;
    private float64 _Elapsed = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientHeld", n"OnClientHeld", k_SlowPolls);
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
        utils_foodpiece::Stamp_Holder(_Piece, Get_SubjectEntity());
        Assert_True(_Piece.TryGet_ReplicatedHolder() == Get_SubjectEntity(), "the server's ledger names the subject");
        WaitSeconds(k_HeldSeconds, n"OnServerHeldLongEnough");
    }

    UFUNCTION()
    private void OnServerHeldLongEnough(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_foodpiece::Clear_Holder(_Piece, Get_SubjectEntity());
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(ck::Is_NOT_Valid(_Piece.TryGet_ReplicatedHolder()), "the server's ledger is free");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"free={ck::Is_NOT_Valid(_Piece.TryGet_ReplicatedHolder())}");
        WaitSeconds(2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    private void Record_OwnHolder()
    {
        if (ck::IsValid(_Piece) && _Piece.Has_Fragment(FMars_Fragment_FoodPiece_Holder))
        { _EverHadOwnHolder = true; }
    }

    UFUNCTION()
    private void Is_ClientHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _Piece = Find_FoodPieceNear(_FloorTop);
        Record_OwnHolder();
        Result.Set(ck::IsValid(_Piece) && ck::IsValid(_Piece.TryGet_ReplicatedHolder()));
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Piece.TryGet_ReplicatedHolder() == Get_SubjectEntity(), "the client reads its copy of the subject as the holder");
        WaitUntil(n"Is_ClientFree", n"OnClientFree", k_SlowPolls);
    }

    // Free, or the clear did not reach the client within its time (measured from the first frame it could have).
    UFUNCTION()
    private void Is_ClientFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Record_OwnHolder();
        if (ck::Is_NOT_Valid(_Piece.TryGet_ReplicatedHolder()))
        {
            Result.Set(true);
            return;
        }

        if (_ClearedAt.IsSet() == false)
        { _ClearedAt = TOptional<float64>(Get_Now() + float64(k_HeldSeconds)); }

        _Elapsed = Get_Now() - _ClearedAt.GetValue();
        Result.Set(_Elapsed > k_ClearSeconds);
    }

    UFUNCTION()
    private void OnClientFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(ck::Is_NOT_Valid(_Piece.TryGet_ReplicatedHolder()), f"the client reads no holder within {k_ClearSeconds} s of the clear");
        Assert_False(_EverHadOwnHolder, "the client's own holder fragment was never added");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"free={ck::Is_NOT_Valid(_Piece.TryGet_ReplicatedHolder())} ownHolder={_EverHadOwnHolder}");
        End_Client();
    }
}
