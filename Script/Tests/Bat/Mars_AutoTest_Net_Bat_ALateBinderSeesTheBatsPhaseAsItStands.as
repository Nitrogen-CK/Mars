// A Cellar Bat born hovering: the server holds its ledger at Hovering and the roost's anchor from the spawn frame on
// (its own requests dropped, so it stays at the hang point). The client's copy takes that state as it stands at its
// ledger's first application: it reads Hovering with the held anchor from its first frame, its phase clock running
// from then on, and raises no OnPhaseChanged (nothing is announced as it stands). A phase that arrives later is
// announced, as the patrol and wake rows prove.
// Surface: Ck.Bat.Net.AS_Bat_ALateBinderSeesTheBatsPhaseAsItStands
class UCk_AutoTest_Net_Bat_ALateBinderSeesTheBatsPhaseAsItStands : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(664000.0, 0.0, 5000.0);
    private const float32 k_HoldSeconds = 4.0f;
    private const float32 k_MinClockSeconds = 0.8f;
    private const float32 k_MaxClockSeconds = 3.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        _HeldLedger = TOptional<FMars_Fragment_Bat_Net>(Make_HeldBatLedger());
        Begin_ServerWorld(n"OnServerReady");
    }

    // Both machines compute it alike: hovering, hanging from the roost's anchor.
    private FMars_Fragment_Bat_Net Make_HeldBatLedger() const
    {
        auto Ledger = FMars_Fragment_Bat_Net();
        Ledger.Phase = EMars_Bat_Phase::Hovering;
        Ledger.PerchAnchor = Get_RoostAnchor();
        return Ledger;
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_HoldSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FromHang = Get_BatFromHang();
        Assert_True(Get_HasBatLedger(), "the server's bat has its ledger");
        Assert_True(Get_BatLedger().Phase == EMars_Bat_Phase::Hovering, f"the server's ledger reads Hovering (reads {Get_BatLedger().Phase :n})");
        Assert_True(Get_BatLedger().PerchAnchor.Equals(Get_RoostAnchor(), 0.01), "the server's ledger reads the roost's anchor");
        Assert_True(FromHang <= 1.0, f"the server's root is within 1 of the hang point (reads {FromHang})");
        Hold_BatServerRow("ALateBinderSeesTheBatsPhaseAsItStands", "");
    }

    UFUNCTION()
    private void Is_CopyHovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_Phase() == EMars_Bat_Phase::Hovering);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CopyHovering", n"OnClientHovering", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientHovering(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto FromHang = Get_BatFromHang();
        const auto Held = Make_HeldBatLedger();
        const auto First = TryGet_BatFirstNotifyLedger();
        const auto PhaseClock = _Bat.Get_PhaseClock();
        const auto Path = _BatPhases.Num() == 0 ? FString("stood") : FString("arrived");
        Log_BatRow("ALateBinderSeesTheBatsPhaseAsItStands", f"path={Path}");

        Assert_True(Get_BatInitialState() == EMars_Net_InitialState::Taken, "the client's copy has taken the state it was born into");
        Assert_True(_BatInitialAtFind == EMars_Net_InitialState::Awaited, "the client found its copy before it took that state");
        Assert_True(First.IsSet(), "the client recorded its ledger's first rep-notify");
        if (First.IsSet())
        {
            Assert_True(First.GetValue().Phase == EMars_Bat_Phase::Hovering, f"the first notify carried Hovering (got {First.GetValue().Phase :n})");
            Assert_True(First.GetValue().PerchAnchor.Equals(Held.PerchAnchor, 0.01), "the first notify carried the held anchor");
        }

        Assert_Equals_Int(_BatPhases.Num(), 0, f"the client raised no OnPhaseChanged (got [{Describe_BatPhases()}])");
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Hovering, "the client's bat hovers");
        Assert_True(Get_HasBatLedger(), "the client's copy has its ledger");
        Assert_True(Get_BatLedger().Phase == EMars_Bat_Phase::Hovering, "the client's ledger reads Hovering");
        Assert_True(_Bat.Get_PerchAnchor().Equals(Held.PerchAnchor, 0.01),
            f"the client's copy hangs from the held anchor (reads {_Bat.Get_PerchAnchor().ToString()})");
        Assert_True(PhaseClock >= k_MinClockSeconds && PhaseClock <= k_MaxClockSeconds,
            f"the copy's phase clock runs from its first notify (reads {PhaseClock})");
        Assert_True(FromHang <= 1.0, f"the client's root is within 1 of the hang point (reads {FromHang})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
