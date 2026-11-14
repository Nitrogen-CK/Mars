// A client fires the same claim twice in one frame: whichever begins first on the authority is applied (the target drops
// to 80), the other is refused as TooSoon. The result does not depend on the order they begin in.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_TwoClaimsInOneFrameApplyOnce
class UCk_AutoTest_Net_HeldItemUse_TwoClaimsInOneFrameApplyOnce : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(523000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);
        Start_ClaimRow();
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(1, 1, TOptional<EMars_HeldItemUse_StrikeRefusal>(EMars_HeldItemUse_StrikeRefusal::TooSoon));
        Assert_True(Get_IsCurrent(80.0f), "the server's target reads 80");
        Hold_ServerRow("TwoClaimsInOneFrameApplyOnce", "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Claim = Make_Claim();
        Fire_Claim(Claim);
        Fire_Claim(Claim);
        WaitUntil(n"Is_ClientAt80", n"OnClientAt80", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientAt80(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(80.0f));
    }

    UFUNCTION()
    private void OnClientAt80(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCurrent(80.0f), "the client's target reads 80");
        Finish_Row("TwoClaimsInOneFrameApplyOnce", "");
    }
}
