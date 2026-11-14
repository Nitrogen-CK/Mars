// A client claims a blow, then another 0.6 s later (past half the cleaver's swing): both are applied and the target
// reads 60 on both machines.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AClaimAfterTheSwingsTimeAppliesAgain
class UCk_AutoTest_Net_HeldItemUse_AClaimAfterTheSwingsTimeAppliesAgain : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(524000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);
        _WatchSeconds = 5.0f;
        Start_ClaimRow();
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(2, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_True(Get_IsCurrent(60.0f), "the server's target reads 60");
        Hold_ServerRow("AClaimAfterTheSwingsTimeAppliesAgain", "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Fire_Claim(Make_Claim());
        WaitSeconds(k_ClaimSpacingSeconds, n"OnClientSecondClaim");
    }

    UFUNCTION()
    private void OnClientSecondClaim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Fire_Claim(Make_Claim());
        WaitUntil(n"Is_ClientAt60", n"OnClientAt60", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientAt60(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(60.0f));
    }

    UFUNCTION()
    private void OnClientAt60(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCurrent(60.0f), "the client's target reads 60");
        Finish_Row("AClaimAfterTheSwingsTimeAppliesAgain", "");
    }
}
