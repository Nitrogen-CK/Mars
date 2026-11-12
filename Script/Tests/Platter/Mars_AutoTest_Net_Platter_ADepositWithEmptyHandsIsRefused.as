// The subject holds nothing. Once the platter is built the server reports step 1 and watches 5 s. At step 1 the client
// records its platter's refusal serial and deposits through the deposit's cue: its ledger then reads one more, refused
// NoFoodInHand naming its subject, and its platter reads nothing held or on its books. At the end the server's platter was
// asked to load nothing and its ledger reads serial 1, NoFoodInHand, naming the subject.
// Surface: Ck.Platter.Net.AS_Platter_ADepositWithEmptyHandsIsRefused
class UCk_AutoTest_Net_Platter_ADepositWithEmptyHandsIsRefused : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 261000.0;
    private const float32 k_WatchSeconds = 5.0f;

    private int32 _SerialAtDeposit = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    protected void On_ServerPlatterReady() override
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Accepted + _Refused, 0, "the server's platter was asked to load nothing");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 1, "the server's ledger reads serial 1");
        Assert_True(_Platter.Get_LastRefusal() == EMars_Interaction_FailReason::NoFoodInHand,
            f"the server's ledger says NoFoodInHand (got [{_Platter.Get_LastRefusal() :n}])");
        Assert_True(Get_PlatterLedgerNamesSubject(), "the server's ledger names the subject");
        End_PlatterServer(f"{Describe_Counts()} {Describe_Signals()} {Describe_PlatterLedger()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _SerialAtDeposit = _Platter.Get_RefusalSerial();
        Deposit();
        WaitUntil(n"Is_ClientRefused", n"OnClientRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_Platter) && _Platter.Get_RefusalSerial() > _SerialAtDeposit);
    }

    UFUNCTION()
    private void OnClientRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), _SerialAtDeposit + 1, "the client's ledger reads one more refusal");
        Assert_True(_Platter.Get_LastRefusal() == EMars_Interaction_FailReason::NoFoodInHand,
            f"the client's ledger says NoFoodInHand (got [{_Platter.Get_LastRefusal() :n}])");
        Assert_True(Get_PlatterLedgerNamesSubject(), "the client's ledger names its subject");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the client's platter reads nothing held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the client's platter reads nothing on its books");
        End_PlatterClient(f"serialAtDeposit={_SerialAtDeposit} {Describe_Counts()} {Describe_PlatterLedger()}");
    }
}
