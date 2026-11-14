// The striker holds nothing: a client's claim naming the cleaver is refused as ItemMismatch and the target keeps its 100.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AClaimWithEmptyHandsIsRefused
class UCk_AutoTest_Net_HeldItemUse_AClaimWithEmptyHandsIsRefused : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(522000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);
        _ServerArms = ECk_EnableDisable::Disable;
        Start_ClaimRow();
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(0, 1, TOptional<EMars_HeldItemUse_StrikeRefusal>(EMars_HeldItemUse_StrikeRefusal::ItemMismatch));
        Assert_True(Get_IsCurrent(100.0f), "the server's target keeps 100");
        Hold_ServerRow("AClaimWithEmptyHandsIsRefused", "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Fire_Claim(Make_Claim());
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCurrent(100.0f), "the client's target keeps 100");
        Finish_Row("AClaimWithEmptyHandsIsRefused", "");
    }
}
