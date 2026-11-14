// A client swings the cleaver at a fig vine's fruit, hanging level with its hand: the claim reaches the authority, whose
// vine's Health empties and releases the fruit (Depleted). On both machines the forage reads exhausted, one fig lies near
// the base, and on the client the forage raised OnReleased and OnExhausted once each and the vine's zone is disabled.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AClientsSwingFellsAVineOnBothMachines
class UCk_AutoTest_Net_HeldItemUse_AClientsSwingFellsAVineOnBothMachines : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(527000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Strike(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToSwing", n"OnClientReadyToSwing", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Arm_Server();
        WaitUntil(n"Is_Armed", n"OnServerArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFigVine();
        WaitUntil(n"Is_VineFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Exhausted", n"OnServerExhausted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Exhausted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Forage) && _Forage.Get_IsExhausted());
    }

    UFUNCTION()
    private void OnServerExhausted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldExhausted");
    }

    UFUNCTION()
    private void OnServerHeldExhausted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Figs = Count_FigsNear();
        const auto Distances = _Damaged.Num() > 0 ? Describe_Distances(_Damaged[0].Event.Hit.Location) : FString();
        Log_Row("AClientsSwingFellsAVineOnBothMachines", f"figs={Figs} {Distances}");
        Assert_Tally(1, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_Equals_Int(_Released, 1, "the server's forage released once");
        Assert_True(_LastReleaseReason.IsSet() && _LastReleaseReason.GetValue() == EMars_Forage_ReleaseReason::Depleted,
            "the server's forage released as Depleted");
        Assert_Equals_Int(Figs, 1, "one fig lies near the server's base");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientReadyToSwing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsArmed() && Get_IsVineFound() && Get_IsZoneSweepable());
    }

    UFUNCTION()
    private void OnClientReadyToSwing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Swing_FromTheHand();
        WaitUntil(n"Is_ClientFelled", n"OnClientFelled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientFelled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Forage) && _Forage.Get_IsExhausted() && Count_FigsNear() >= 1);
    }

    UFUNCTION()
    private void OnClientFelled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Figs = Count_FigsNear();
        const auto SweepHit = _SwingHit.Get_HitLocation();
        Log_Row("AClientsSwingFellsAVineOnBothMachines", f"figs={Figs} sweepHit={SweepHit} sweepKind={_SwingHit.Get_HitKind() :n}");
        Assert_True(_Forage.Get_IsExhausted(), "the client's forage reads exhausted");
        Assert_Equals_Int(_Released, 1, "the client's forage raised OnReleased once");
        Assert_Equals_Int(_Exhausted, 1, "the client's forage raised OnExhausted once");
        Assert_False(_Zone.Get_IsEnabled(), "the client's vine zone is disabled");
        Assert_Equals_Int(Figs, 1, "one fig lies near the client's base");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
