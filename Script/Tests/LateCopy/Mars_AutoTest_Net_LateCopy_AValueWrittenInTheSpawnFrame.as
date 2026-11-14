// The server spawns the probe with its ledger already reading 7 in the spawn frame, so the entity and its value reach
// the client together, as an old entity does for a joiner. The client's copy reads 7, its mirror has run, the
// replication-complete promise fired and read 7, and no notify was taken before the construct. The order the copy
// takes the state it was born into: the ledger was not there when it composed, its mirror's first pass read the
// default, and the ledger's first application, the first notify, carried 7 and was taken as it stands.
class UCk_AutoTest_Net_LateCopy_AValueWrittenInTheSpawnFrame : UMars_AutoTestRig_NetLateCopy
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(650000.0, 0.0, 5000.0);
    private const float32 k_ServerHoldAfterSpawnSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_LedgerFinal", n"OnClientFinal", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerProbe(k_FinalValue, EMars_TESTONLY_LateCopy_Compose::AtConstruct);
        WaitUntil(n"Is_ProbeFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldAfterSpawnSeconds, n"OnServerHeldProbe");
    }

    UFUNCTION()
    private void OnServerHeldProbe(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AValueWrittenInTheSpawnFrame");
        const auto Record = Get_Record();
        Assert_Equals_Int(Get_LedgerValue(), k_FinalValue, "the server's ledger reads 7");
        Assert_True(Record.Mirror.Frame >= 0, "the server's mirror has run");
        Assert_Equals_Int(Record.Mirror.Value, k_FinalValue, "the server's mirror read 7 on its first pass");
        Assert_Equals_Int(Record.Notifies.Num(), 0, "the server took no notify");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFinal(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AValueWrittenInTheSpawnFrame");
        const auto Record = Get_Record();
        Assert_Equals_Int(Get_LedgerValue(), k_FinalValue, "the client's ledger reads 7");
        Assert_True(Record.Mirror.Frame >= 0, "the client's mirror has run");
        Assert_True(Record.Promise.Frame >= 0, "the client's replication-complete promise fired");
        Assert_Equals_Int(Record.Promise.Value, k_FinalValue, "the client's ledger read 7 when the promise fired");
        Assert_True(Get_AreNotifiesAfterConstruct(), "no notify was taken before the client's construct");
        Assert_False(Record.HadLedgerAtCompose, "the ledger was not on the client's copy when it composed");
        Assert_Equals_Int(Record.Mirror.Value, 0, "the client's mirror read 0 on its first pass");
        Assert_True(Record.Notifies.Num() > 0, "the client took a notify");
        if (Record.Notifies.Num() > 0)
        {
            Assert_Equals_Int(Record.Notifies[0].Value, k_FinalValue, "the client's first notify read 7");
            Assert_True(Record.Notifies[0].Way == EMars_TESTONLY_LateCopy_Reconcile::AsItStands,
                "the client's first notify was taken as it stands");
        }

        Assert_Equals_Int(Get_NotifyCount(EMars_TESTONLY_LateCopy_Reconcile::AsItArrives), 0,
            "no notify on the client was taken as it arrives");
        Assert_True(Get_InitialState() == EMars_Net_InitialState::Taken, "the client's copy has taken its initial state");
        Assert_True(Get_Path() == "stood", "the value was taken as the state the copy was born into");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
