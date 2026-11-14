// The target stands 1000 cm from the hand on +X. A client claims a blow on its face (far beyond the cleaver's reach),
// then 0.6 s later a blow on that zone 50 cm in front of the hand (far from every hurtbox of the zone): both are refused
// as OutOfReach and the target keeps its 100.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AClaimOutOfReachIsRefused
class UCk_AutoTest_Net_HeldItemUse_AClaimOutOfReachIsRefused : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(525000.0, 0.0, 5000.0);
    private const float64 k_TargetFromHand = 1000.0;
    private const float64 k_NearHandContact = 50.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);
        _TargetAt = FVector(Get_HandLocation().X + k_TargetFromHand, k_Base.Y, k_Base.Z);
        _WatchSeconds = 5.0f;
        Start_ClaimRow();
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(0, 2, TOptional<EMars_HeldItemUse_StrikeRefusal>(EMars_HeldItemUse_StrikeRefusal::OutOfReach));
        Assert_True(Get_IsCurrent(100.0f), "the server's target keeps 100");
        Hold_ServerRow("AClaimOutOfReachIsRefused", "");
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
        auto Claim = Make_Claim();
        Claim.Location = Get_HandLocation() + FVector::ForwardVector * k_NearHandContact;
        Fire_Claim(Claim);
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCurrent(100.0f), "the client's target keeps 100");
        Finish_Row("AClaimOutOfReachIsRefused", "");
    }
}
