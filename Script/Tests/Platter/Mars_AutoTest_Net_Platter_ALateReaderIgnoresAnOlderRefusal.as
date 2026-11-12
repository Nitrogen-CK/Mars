// An older refusal is standing state, not news. In the continuation in which the server first finds its platter it asks it
// for a deposit by the subject, whose hands are empty (refused NoFoodInHand, serial 1), and holds 4 s. The client records
// the serial it reads when it finds its own platter, waits until its ledger reads serial 1 naming its subject, and then
// for 2 s the serial does not advance; at the end its ledger reads serial 1, NoFoodInHand, naming its subject. The client
// logs the serial it read on finding its platter.
// Surface: Ck.Platter.Net.AS_Platter_ALateReaderIgnoresAnOlderRefusal
class UCk_AutoTest_Net_Platter_ALateReaderIgnoresAnOlderRefusal : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 268000.0;
    private const float32 k_RefusedHoldSeconds = 4.0f;
    private const float32 k_QuietSeconds = 2.0f;

    // Client: the serial it read on finding its platter, the one it read once serial 1 stood, and the frames between.
    private int32 _SerialAtFind = -1;
    private int32 _SerialStanding = -1;
    private int64 _FindFrame = -1;
    private int64 _StandingFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientPlatterFound", n"OnClientPlatterFound", k_SlowPolls); }
    }

    protected void On_ServerPlatterReady() override
    {
        _Platter.Request_Deposit(FMars_Request_Platter_Deposit(Get_SubjectEntity()));
        WaitSeconds(k_RefusedHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 1, "the server's ledger reads serial 1");
        Assert_True(_Platter.Get_LastRefusal() == EMars_Interaction_FailReason::NoFoodInHand,
            f"the server's ledger says NoFoodInHand (got [{_Platter.Get_LastRefusal() :n}])");
        Assert_True(Get_PlatterLedgerNamesSubject(), "the server's ledger names the subject");
        End_PlatterServer(f"{Describe_Counts()} {Describe_PlatterLedger()}");
    }

    UFUNCTION()
    private void Is_ClientPlatterFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindPlatter());
    }

    UFUNCTION()
    private void OnClientPlatterFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtFind = _Platter.Get_RefusalSerial();
        _FindFrame = utils_time::Get_FrameCounter();
        WaitUntil(n"Is_ClientRefusalStanding", n"OnClientRefusalStanding", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRefusalStanding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_Platter) && _Platter.Get_RefusalSerial() == 1 && Get_PlatterLedgerNamesSubject());
    }

    UFUNCTION()
    private void OnClientRefusalStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialStanding = _Platter.Get_RefusalSerial();
        _StandingFrame = utils_time::Get_FrameCounter();
        WaitSeconds(k_QuietSeconds, n"OnClientQuiet");
    }

    UFUNCTION()
    private void OnClientQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), _SerialStanding, "the client's serial did not advance for 2 s");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 1, "the client's ledger reads serial 1");
        Assert_True(_Platter.Get_LastRefusal() == EMars_Interaction_FailReason::NoFoodInHand,
            f"the client's ledger says NoFoodInHand (got [{_Platter.Get_LastRefusal() :n}])");
        Assert_True(Get_PlatterLedgerNamesSubject(), "the client's ledger names its subject");
        End_PlatterClient(f"serialAtFind={_SerialAtFind} findToStandingFrames={_StandingFrame - _FindFrame} {Describe_Counts()} {Describe_PlatterLedger()}");
    }
}
