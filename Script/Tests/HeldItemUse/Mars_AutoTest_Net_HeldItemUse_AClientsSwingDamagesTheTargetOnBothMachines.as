// A client swings the cleaver at the target as the strike task does: its own dealer raises OnDamageDealt at once (the
// blow shows), and the claim it fires reaches the authority, which applies it through its copy of the striker's dealer.
// The target reads 80 on both machines and raised OnDamaged once on each, the client's at the location its sweep hit.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AClientsSwingDamagesTheTargetOnBothMachines
class UCk_AutoTest_Net_HeldItemUse_AClientsSwingDamagesTheTargetOnBothMachines : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(520000.0, 0.0, 5000.0);
    private const float64 k_LocationToleranceCm = 1.0;

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
        Spawn_ServerTarget(ECk_Team_ID::Two);
        WaitUntil(n"Is_TargetFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_At80", n"OnServerAt80", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_At80(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(80.0f));
    }

    UFUNCTION()
    private void OnServerAt80(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAt80");
    }

    UFUNCTION()
    private void OnServerHeldAt80(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Distances = _Damaged.Num() > 0 ? Describe_Distances(_Damaged[0].Event.Hit.Location) : FString();
        Log_Row("AClientsSwingDamagesTheTargetOnBothMachines", Distances);
        Assert_Tally(1, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the server's dealer dealt one hit");
        Assert_Equals_Int(_Dealt, 1, "the server's dealer raised OnDamageDealt once");
        Assert_Equals_Int(_Damaged.Num(), 1, "the server's target raised OnDamaged once");
        if (_Damaged.Num() > 0)
        { Assert_Equals_Float(_Damaged[0].Applied, 20.0f, 0.01f, "the server's target took the cleaver's 20"); }

        Assert_True(Get_IsCurrent(80.0f), "the server's target reads 80");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientReadyToSwing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsArmed() && Get_IsTargetFound() && Get_IsZoneSweepable());
    }

    UFUNCTION()
    private void OnClientReadyToSwing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Swing_FromTheHand();
        WaitUntil(n"Is_At80", n"OnClientAt80", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAt80(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto SweepHit = _SwingHit.Get_HitLocation();
        const auto Line = f"sweepHit={SweepHit} sweepKind={_SwingHit.Get_HitKind() :n}";
        Log_Row("AClientsSwingDamagesTheTargetOnBothMachines", Line);
        Assert_Equals_Int(_Dealt, 1, "the client's dealer raised OnDamageDealt once");
        Assert_Equals_Int(_Damaged.Num(), 1, "the client's target raised OnDamaged once");
        if (_Damaged.Num() > 0)
        {
            Assert_Equals_Int(_Damaged[0].DealtBefore, 1, "the client's dealer raised OnDamageDealt before its target's Health changed");
            const auto Off = (_Damaged[0].Event.Hit.Location - SweepHit).Size();
            Assert_True(Off <= k_LocationToleranceCm, f"the client's OnDamaged lands where its sweep hit (off by {Off} cm)");
        }

        Assert_True(Get_IsCurrent(80.0f), "the client's target reads 80");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
