// The target is on the striker's team. A client's claim is applied (the authority's checks pass), and the striker's
// dealer on the authority rejects the blow as Friendly: the target keeps its 100.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AFriendlyTargetTakesNoDamage
class UCk_AutoTest_Net_HeldItemUse_AFriendlyTargetTakesNoDamage : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(528000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);
        _TargetTeam = ECk_Team_ID::One;
        Start_ClaimRow();
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(1, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_Equals_Int(_Rejected, 1, "the server's dealer raised OnDamageRejected once");
        Assert_True(_LastRejectReason.IsSet() && _LastRejectReason.GetValue() == EMars_DamageDealer_RejectReason::Friendly,
            "the server's dealer rejected the blow as Friendly");
        Assert_True(Get_IsCurrent(100.0f), "the server's target keeps 100");
        Hold_ServerRow("AFriendlyTargetTakesNoDamage", "");
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
        Finish_Row("AFriendlyTargetTakesNoDamage", "");
    }
}
