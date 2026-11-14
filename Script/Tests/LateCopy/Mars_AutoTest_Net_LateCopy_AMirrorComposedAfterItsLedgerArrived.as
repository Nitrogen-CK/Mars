// The server spawns the probe with its ledger reading 7 in the spawn frame, and the client's copy composes its kernel
// only when the row asks, once its ledger already reads 7: a kernel composed after its ledger's first application. Its
// compose finds the ledger and takes it then, its mirror's first pass reads 7 as it stands, and the server's later
// write of 9 is the one notify, taken as it arrives.
class UCk_AutoTest_Net_LateCopy_AMirrorComposedAfterItsLedgerArrived : UMars_AutoTestRig_NetLateCopy
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(653000.0, 0.0, 5000.0);
    // The server writes this long after it finds its probe, once the client has composed on its ledger.
    private const float32 k_ServerWriteAfterFoundSeconds = 4.0f;
    private const int32 k_LaterValue = 9;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        _PathValue = k_LaterValue;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_LedgerFinal", n"OnClientLedgerStands", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerProbe(k_FinalValue, EMars_TESTONLY_LateCopy_Compose::WhenAsked);
        WaitUntil(n"Is_ProbeFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWriteAfterFoundSeconds, n"OnServerWrite");
    }

    UFUNCTION()
    private void OnServerWrite(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_late_copy_probe::Write(_Probe, k_LaterValue);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldProbe");
    }

    UFUNCTION()
    private void OnServerHeldProbe(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AMirrorComposedAfterItsLedgerArrived");
        const auto Record = Get_Record();
        Assert_Equals_Int(Get_LedgerValue(), k_LaterValue, "the server's ledger reads 9");
        Assert_Equals_Int(Record.Mirror.Value, k_FinalValue, "the server's mirror read 7 on its first pass");
        Assert_Equals_Int(Record.Notifies.Num(), 0, "the server took no notify");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    // The copy's ledger already reads 7 and its kernel has not composed: compose it now.
    UFUNCTION()
    private void OnClientLedgerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_late_copy_probe::Compose(_Probe);
        WaitUntil(n"Is_LedgerLater", n"OnClientLater", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_LedgerLater(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsProbeFound() && Get_LedgerValue() == k_LaterValue);
    }

    UFUNCTION()
    private void OnClientLater(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AMirrorComposedAfterItsLedgerArrived");
        const auto Record = Get_Record();
        Assert_True(Record.HadLedgerAtCompose, "the ledger was on the client's copy when it composed");
        Assert_True(Record.InitialStateAtCompose == EMars_Net_InitialState::Taken,
            "the client's copy took its initial state at its compose");
        Assert_True(Record.Mirror.Frame >= 0, "the client's mirror has run");
        Assert_Equals_Int(Record.Mirror.Value, k_FinalValue, "the client's mirror read 7 on its first pass");
        Assert_Equals_Int(Record.Notifies.Num(), 1, "the client took exactly one notify");
        if (Record.Notifies.Num() == 1)
        {
            Assert_Equals_Int(Record.Notifies[0].Value, k_LaterValue, "the client's notify read 9");
            Assert_True(Record.Notifies[0].Way == EMars_TESTONLY_LateCopy_Reconcile::AsItArrives,
                "the client's notify was taken as it arrives");
        }

        Assert_True(Get_Path() == "arrived", "the later write arrived as a change");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
