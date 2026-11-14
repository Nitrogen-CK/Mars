// A client claims its copy's root with zone index 5 (the root has one zone), then 0.6 s later index 0 of the subject (an
// entity with no zone): both are refused as NoZone, nothing is applied and the target keeps its 100.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AClaimOnAZoneThatIsNotThereIsRefused
class UCk_AutoTest_Net_HeldItemUse_AClaimOnAZoneThatIsNotThereIsRefused : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(526000.0, 0.0, 5000.0);
    private const int32 k_MissingZoneIndex = 5;

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
        Assert_Tally(0, 2, TOptional<EMars_HeldItemUse_StrikeRefusal>(EMars_HeldItemUse_StrikeRefusal::NoZone));
        Assert_True(Get_IsCurrent(100.0f), "the server's target keeps 100");
        Hold_ServerRow("AClaimOnAZoneThatIsNotThereIsRefused", "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Claim = Make_Claim();
        Claim.ZoneIndex = k_MissingZoneIndex;
        Fire_Claim(Claim);
        WaitSeconds(k_ClaimSpacingSeconds, n"OnClientSecondClaim");
    }

    UFUNCTION()
    private void OnClientSecondClaim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Claim = Make_Claim();
        Claim.ZoneRoot = Get_SubjectEntity();
        Claim.ZoneIndex = 0;
        Fire_Claim(Claim);
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCurrent(100.0f), "the client's target keeps 100");
        Finish_Row("AClaimOnAZoneThatIsNotThereIsRefused", "");
    }
}
