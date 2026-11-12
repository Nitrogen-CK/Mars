// An older refusal naming the subject is standing state, not the answer to a later act. Once its docks are composed the
// server asks the empty Input dock for a Take by the subject, which the dock refuses NoLongerDocked (serial 1); then it
// docks the platter on the Input dock (step 1) and step 2 follows once the subject's overflow holds it. The client waits
// until its own ledger reads serial 1 naming its subject and its Input dock offers Take, records the serial, and asks for
// the Take through the dock's Act, judging it as the dock's task does: the effect landed (the dock no longer holds the item
// and the subject's hotbar does), or a refusal newer than the recorded serial names the subject. Its act ends on the
// effect, the serial it recorded at the act was 1, and the ledger still reads serial 1 afterwards on both machines.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ALateReaderIgnoresAnOlderRefusal
class UCk_AutoTest_Net_PlatterDock_ALateReaderIgnoresAnOlderRefusal : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 259000.0;

    private int32 _SerialAtAct = -1;
    private bool _EndedOnEffect = false;
    private bool _EndedRefused = false;

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
        Spawn_ServerStation();
    }

    protected void On_ServerDocksReady() override
    {
        _InputDock.Request_Act(FMars_Request_PlatterDock_Act(Get_SubjectEntity(), EMars_PlatterDock_Action::Take));
        WaitUntil(n"Is_ServerRefused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_InputDock.Get_RefusalSerial() == 1);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_InputDock.Get_LastRefusal() == EMars_Interaction_FailReason::NoLongerDocked,
            f"the server's ledger says NoLongerDocked (got [{_InputDock.Get_LastRefusal() :n}])");
        Assert_True(Get_LedgerNamesSubject(_InputDock), "the server's ledger names the subject");
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitUntil(n"Is_ServerOverflowHolds", n"OnServerOverflowHolds", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOverflowHolds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_OverflowItem() == Get_PlatterItem());
    }

    UFUNCTION()
    private void OnServerOverflowHolds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_Location(2, FVector::ZeroVector);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 1, "the server's ledger still reads serial 1");
        Assert_False(_InputDock.Get_IsOccupied(), "the server's Input dock is empty");
        End_DockServer(f"{Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            WaitUntil(n"Is_OlderRefusalStanding", n"OnOlderRefusalStanding", k_SlowPolls);
            return;
        }

        const auto Fault = Get_HeldFault();
        Assert_True(_EndedOnEffect && _EndedRefused == false, f"the client's act ended on its effect (effect={_EndedOnEffect} refused={_EndedRefused})");
        Assert_Equals_Int(_SerialAtAct, 1, "the serial the client recorded at its act was 1");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 1, "the client's ledger still reads serial 1");
        Assert_False(_InputDock.Get_IsOccupied(), "the client's Input dock is empty");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Held by the subject ({Fault})");
        End_DockClient(f"serialAtAct={_SerialAtAct} effect={_EndedOnEffect} refused={_EndedRefused} held=[{Fault}] {Describe_ActFrames()} {Describe_Ledger(_InputDock)}");
    }

    UFUNCTION()
    private void Is_OlderRefusalStanding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_InputDock.Get_RefusalSerial() == 1 && Get_LedgerNamesSubject(_InputDock)
            && _InputDock.Get_ActionFor(Get_SubjectEntity()) == EMars_PlatterDock_Action::Take);
    }

    UFUNCTION()
    private void OnOlderRefusalStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtAct = _InputDock.Get_RefusalSerial();
        Act(_InputDock, EMars_PlatterDock_Action::Take);
        WaitUntil(n"Is_ActAnswered", n"OnActAnswered", k_SlowPolls);
    }

    // The dock task's judgement: the effect, or a refusal newer than the recorded serial that names this initiator.
    UFUNCTION()
    private void Is_ActAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Item = Get_PlatterItem();
        _EndedOnEffect = _InputDock.Get_Item() != Item && _Carrier.Hotbar.TryGet_SlotIndexOf(Item).IsSet();
        _EndedRefused = _EndedOnEffect == false && _InputDock.Get_RefusalSerial() > _SerialAtAct && Get_LedgerNamesSubject(_InputDock);
        if (_EndedOnEffect)
        { Record_EffectFrame(); }

        auto Result = OutResult;
        Result.Set(_EndedOnEffect || _EndedRefused);
    }

    UFUNCTION()
    private void OnActAnswered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Step(2);
    }
}
