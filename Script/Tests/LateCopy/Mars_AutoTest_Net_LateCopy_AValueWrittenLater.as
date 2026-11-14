// The control: the server spawns the probe with its ledger at the default and writes 7 once the client's copy has had
// time to compose. The client's mirror read 0 on its first pass and exactly one notify brought 7: the value arrived.
class UCk_AutoTest_Net_LateCopy_AValueWrittenLater : UMars_AutoTestRig_NetLateCopy
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(651000.0, 0.0, 5000.0);

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
        Spawn_ServerProbe(0);
        WaitUntil(n"Is_ProbeFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_late_copy_probe::Write(_Probe, k_FinalValue);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldProbe");
    }

    UFUNCTION()
    private void OnServerHeldProbe(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AValueWrittenLater");
        const auto Record = Get_Record();
        Assert_Equals_Int(Get_LedgerValue(), k_FinalValue, "the server's ledger reads 7");
        Assert_Equals_Int(Record.Mirror.Value, 0, "the server's mirror read 0 on its first pass");
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
        Log_Row("AValueWrittenLater");
        const auto Record = Get_Record();
        Assert_Equals_Int(Record.Mirror.Value, 0, "the client's mirror read 0 on its first pass");
        // The arrival of the entity itself may raise a notify carrying the default; only the write brings 7.
        auto NotifiesOfSeven = 0;
        for (auto Notify : Record.Notifies)
        {
            if (Notify.Value == k_FinalValue)
            { ++NotifiesOfSeven; }
        }

        Assert_Equals_Int(NotifiesOfSeven, 1, "exactly one notify on the client brought 7");

        Assert_True(Get_Path() == "arrived", "the value arrived after the mirror's first pass");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
