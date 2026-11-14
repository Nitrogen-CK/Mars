// The server's den lets its one resident out one frame after it composes, before the client's copy can have bound: the
// client's copy shows the eyes vacant as the server's are, whether the ledger already stood when it bound (no change
// raised there) or arrived after (one change). The log names the path that ran.
// Surface: Ck.RatDen.Net.AS_RatDen_ALateBinderSeesTheEyesAsTheyStand
class UCk_AutoTest_Net_RatDen_ALateBinderSeesTheEyesAsTheyStand : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(677000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const FString k_Row = "ALateBinderSeesTheEyesAsTheyStand";

    private int32 _ServerWriteFrame = -1;
    private int32 _ClientFoundFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowDenFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDen(1);
        WaitUntil(n"Is_ServerDenSettled", n"OnServerDenSettled", k_SlowPolls);
    }

    // The den is composed and has no request waiting.
    UFUNCTION()
    private void Is_ServerDenSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowDenFound() && _RowDen.Has_Fragment(FMars_Fragment_RatDen_Requests) == false);
    }

    UFUNCTION()
    private void OnServerDenSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, n"OnServerOneFrameLater");
    }

    UFUNCTION()
    private void OnServerOneFrameLater(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ServerWriteFrame = int32(utils_time::Get_FrameCounter());
        _RowDen.Request_Emerge(FMars_Request_RatDen_Emerge(1, 0.0f));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PantryRow(k_Row, f"write={_ServerWriteFrame}");
        Assert_False(_RowDen.Get_EyesShown(), "the server's den shows no eyes");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Vacant, 0), "the server's den ledger reads Vacant");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        TearDown();
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientFoundFrame = int32(utils_time::Get_FrameCounter());
        WaitUntil(n"Is_ClientEyesVacant", n"OnClientEyesVacant", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientEyesVacant(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowEnding(_RowDen) == false && _RowDen.Get_EyesShown() == false);
    }

    UFUNCTION()
    private void OnClientEyesVacant(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowEnding(_RowDen))
        {
            Log_PantryRow(k_Row, "den=gone");
            FinishFailure("the client's den copy was gone before it asserted");
            return;
        }

        FString Path = _EyeChanges.Num() == 0 ? "stood" : "arrived";
        Log_PantryRow(k_Row, f"path={Path} recorded={_EyeChanges.Num()} found={_ClientFoundFrame}");
        Assert_False(_RowDen.Get_EyesShown(), "the client's den copy shows no eyes");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Vacant, 0), "the client's den ledger reads Vacant");
        Assert_True(_EyeChanges.Num() <= 1, f"the client recorded at most one eye change (recorded {_EyeChanges.Num()})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
