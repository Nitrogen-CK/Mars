// A swing abandoned mid-arc stops on the other machine: with the pawn possessed by the client's controller, the client
// starts a chop through the pawn (an impact at 2.0 s, a 0.35 s recovery) and cancels it 0.4 s later through the pawn,
// the call the strike task's exit makes. The server's copy, shown the start, is shown the cancel as well: it goes None
// to Windup, Windup to Recover and Recover to None, never through Strike, and rests within 1.5 s of leaving None. The
// client's own copy does the same. The controller gets its old pawn back only after the client has asserted.
// Surface: Ck.HandSwing.Net.AS_HandSwing_ACancelledSwingStopsOnTheOtherMachine
class UCk_AutoTest_Net_HandSwing_ACancelledSwingStopsOnTheOtherMachine : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(795000.0, 0.0, 5000.0);
    private const FString k_Row = "ACancelledSwingStopsOnTheOtherMachine";
    private const float32 k_ImpactSeconds = 2.0f;
    private const float32 k_RecoverySeconds = 0.35f;
    private const float32 k_CancelAfterSeconds = 0.4f;
    // A cancelled copy rests within this of leaving None; an uncancelled one rests 2.35 s after.
    private const float64 k_MaxSwingSeconds = 1.5;

    private TArray<EMars_HandSwing_Phase> _SwingFrom;
    private TArray<EMars_HandSwing_Phase> _SwingTo;
    private TArray<float64> _SwingClocks;
    private bool _SwingBound = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer())
        { Spawn_ServerPawn(); }

        WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_Player.Is_HandSwing() == false)
        {
            FinishFailure(f"the {Get_MachineName()}'s copy of the pawn composed without a HandSwing");
            return;
        }

        auto Swing = _Player.As_HandSwing();
        Swing.BindTo_OnPhaseChanged(FMars_Delegate_HandSwing_OnPhaseChanged(this, n"OnSwingPhaseChanged"));
        _SwingBound = true;

        if (Get_IsServer())
        {
            WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
            return;
        }

        WaitUntil(n"Is_ClientControlledAndAlive", n"OnClientAlive", k_SlowPolls);
    }

    UFUNCTION()
    private void OnSwingPhaseChanged(FCk_Handle_HandSwing InSwing, EMars_HandSwing_Phase InPrevious, EMars_HandSwing_Phase InNew)
    {
        _SwingFrom.Add(InPrevious);
        _SwingTo.Add(InNew);
        _SwingClocks.Add(utils_mars_net::Get_ServerWorldSeconds(_Player));
    }

    // At rest again after leaving it at least once.
    UFUNCTION()
    private void Is_SwingDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Player) || _Player.Is_HandSwing() == false)
        {
            Result.Set(false);
            return;
        }

        Result.Set(_SwingTo.Num() > 0 && _Player.As_HandSwing().Get_Phase() == EMars_HandSwing_Phase::None);
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_SwingRow("remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        WaitUntil(n"Is_SwingDone", n"OnServerSwingDone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSwingDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_SwingRow("");
        Assert_CancelledChanges();
        if (_SwingClocks.Num() > 0)
        {
            const auto Span = _SwingClocks.Last() - _SwingClocks[0];
            Assert_True(Span <= k_MaxSwingSeconds, f"the server's copy rested {Span} s after leaving None (at most {k_MaxSwingSeconds})");
        }

        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void Is_ClientControlledAndAlive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Pawn.IsLocallyControlled() && Get_IsInState(UMars_SmState_Alive));
    }

    UFUNCTION()
    private void OnClientAlive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Pawn.Request_Strike(FMars_Request_HandSwing_Start(utils_hand_swing::Make_ChopArc(), k_ImpactSeconds, k_RecoverySeconds));
        WaitSeconds(k_CancelAfterSeconds, n"OnClientCancelDue");
    }

    UFUNCTION()
    private void OnClientCancelDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Pawn.Request_CancelStrike();
        WaitUntil(n"Is_SwingDone", n"OnClientSwingDone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSwingDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_SwingRow("");
        Assert_CancelledChanges();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown();
        FinishSuccess();
    }

    // None to Windup, Windup to Recover, Recover to None, and no change names Strike.
    private void Assert_CancelledChanges()
    {
        Assert_Equals_Int(_SwingTo.Num(), 3, f"the {Get_MachineName()}'s copy changed phase three times");
        for (int32 Index = 0; Index < _SwingTo.Num(); ++Index)
        {
            Assert_True(_SwingFrom[Index] != EMars_HandSwing_Phase::Strike && _SwingTo[Index] != EMars_HandSwing_Phase::Strike,
                f"the {Get_MachineName()}'s change {Index} names no Strike");
        }

        if (_SwingTo.Num() != 3)
        { return; }

        Assert_True(_SwingFrom[0] == EMars_HandSwing_Phase::None && _SwingTo[0] == EMars_HandSwing_Phase::Windup, "the first change is None to Windup");
        Assert_True(_SwingFrom[1] == EMars_HandSwing_Phase::Windup && _SwingTo[1] == EMars_HandSwing_Phase::Recover, "the second change is Windup to Recover");
        Assert_True(_SwingFrom[2] == EMars_HandSwing_Phase::Recover && _SwingTo[2] == EMars_HandSwing_Phase::None, "the third change is Recover to None");
    }

    private void Log_SwingRow(FString InExtra)
    {
        auto Changes = FString();
        for (int32 Index = 0; Index < _SwingTo.Num(); ++Index)
        { Changes += f"{_SwingFrom[Index] :n}>{_SwingTo[Index] :n}@{_SwingClocks[Index]} "; }

        const auto IsLocal = ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled();
        const auto HasAuthority = ck::IsValid(_Player) && utils_net::Get_HasAuthority(_Player);
        const auto Line = f"[HandSwingNetTest] {k_Row} {Get_MachineName()} local={IsLocal} authority={HasAuthority} bound={_SwingBound} changes=[{Changes}] ensures={Get_NewEnsures()} {InExtra}";
        Log(Line);
    }
}
