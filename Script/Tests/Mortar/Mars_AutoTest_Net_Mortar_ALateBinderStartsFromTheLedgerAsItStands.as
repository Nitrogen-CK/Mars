// The server spawns a mortar station that engages and strikes a hit as it composes; once its ledger reads that landing
// it holds 4 s, strikes a second hit, and reports once that has landed. The client's copy is born into the first strike
// started and not landed: it raises that strike's landing and the whole second strike, never the first strike's start,
// and nothing in its first notify's frame. Once its ledger reads one landing and one hit its batch shows one hit and it
// reads engaged; at the end its batch reads Grind.
// Surface: Ck.Mortar.Net.AS_Mortar_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Mortar_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 449000.0;
    private const float32 k_HoldBeforeSecondHitSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerOneHit", n"OnClientLedgerOneHit", k_SlowPolls); }
    }

    protected TSubclassOf<UCk_EntityScript_UE> Get_MortarStationClass() const override
    {
        return UMars_TESTONLY_NetMortarStation_BornStriking_EntityScript;
    }

    // The server can find its station before the spawn frame's drain has run: it reads its ledger, not its record.
    protected EMars_TESTONLY_NetMinigameFound On_ServerStationFound() override
    {
        Log_Minigame(f"found: {Describe_Find()} ledger[{Describe_Ledger(_Mortar.Get_Ledger())}]");
        WaitUntil(n"Is_ServerLedgerLandedOnce", n"OnServerLandedOnce", k_SlowPolls);
        return EMars_TESTONLY_NetMinigameFound::TestContinues;
    }

    UFUNCTION()
    private void Is_ServerLedgerLandedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Ledger().LandedSerial >= 1);
    }

    UFUNCTION()
    private void OnServerLandedOnce(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_HoldBeforeSecondHitSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hit_Directly();
        WaitUntil(n"Is_ServerLedgerLandedTwice", n"OnServerLandedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLedgerLandedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Ledger().LandedSerial >= 2);
    }

    UFUNCTION()
    private void OnServerLandedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Mortar.Get_Ledger();
        Assert_Equals_Int(Ledger.StrikeSerial, 2, f"the server's ledger counts two strikes ({Describe_Mortar()})");
        Assert_Equals_Int(Ledger.LandedSerial, 2, f"the server's ledger counts two landings ({Describe_Mortar()})");
        Assert_Equals_Int(Ledger.Batch.CrushHits, 2, f"the server's batch counts two hits ({Describe_Mortar()})");
        Assert_True(Ledger.Batch.Phase == EMars_Mortar_Phase::Grind, f"the server's batch reads Grind ({Describe_Mortar()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_MinigameServer(f"{Describe_Find()} {Describe_Record()} {Describe_Mortar()}");
    }

    // Quiet once the copy is gone: Try_FindStation only finds a live one.
    UFUNCTION()
    private void Is_ClientLedgerOneHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindStation() == false)
        {
            Result.Set(false);
            return;
        }

        const auto Ledger = _Mortar.Get_Ledger();
        Result.Set(Ledger.LandedSerial == 1 && Ledger.Batch.CrushHits == 1);
    }

    UFUNCTION()
    private void OnClientLedgerOneHit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Mortar.Get_Batch().CrushHits, 1, f"the client's batch shows one hit once its ledger reads it ({Describe_Mortar()})");
        Assert_True(_Mortar.Get_IsEngaged(), "the client reads engaged once its ledger reads one hit");
        Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto First = Get_FirstNotifyLedger();
        const auto Ledger = _Mortar.Get_Ledger();
        const auto Line = f"{Describe_Find()} {Describe_Record()} {Describe_Mortar()}";
        Assert_True(Get_MortarInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_InitialAtFind == EMars_Net_InitialState::Awaited, f"the client found its copy before its ledger's first application ({Line})");
        Assert_True(Get_HasFirstNotify(), f"the client recorded a rep-notify of its copy's ledger ({Line})");
        Assert_True(First.StrikeSerial == 1 && First.LandedSerial == 0 && First.Engagement == EMars_Mortar_Engagement::Engaged,
            f"the first notify carried the engaged mortar and the strike it was born into ({Line})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::StrikeStarted), Ledger.StrikeSerial - First.StrikeSerial,
            f"the client started only the strikes after its first notify ({Line})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::StrikeLanded), Ledger.LandedSerial - First.LandedSerial,
            f"the client landed only the strikes after its first notify ({Line})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::BatchChanged), 2, f"the client raised OnBatchChanged twice ({Line})");
        Assert_Equals_Int(Get_SignalsInFrame(Get_FirstNotifyFrame()), 0, f"the client raised nothing in its first notify's frame ({Line})");
        Assert_True(_Signals.Num() > 0 && _Signals[0] == EMars_TESTONLY_NetMortarSignal::StrikeLanded,
            f"the first signal the client raised is a landing ({Line})");
        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Grind, f"the client's batch reads Grind ({Line})");
        End_MinigameClient(Line);
    }
}
