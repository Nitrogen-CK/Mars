// A monster composed with two Break parts: each machine's copy registers both of its own parts (two valid entries on the
// roster, both attached).
// Surface: Ck.Monster.Net.AS_Monster_PartsRegisterOnBothMachines
class UCk_AutoTest_Net_Monster_PartsRegisterOnBothMachines : UMars_AutoTestRig_NetMonster
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(543000.0, 0.0, 5000.0);
    private const int32 k_PartCount = 2;
    private const float32 k_PartsHoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MonsterFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMonster(k_PartCount);
        WaitUntil(n"Is_MonsterFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_PartsHoldSeconds, n"OnServerHeld_Parts");
    }

    UFUNCTION()
    private void OnServerHeld_Parts(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        AssertParts();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        AssertParts();
    }

    private void AssertParts()
    {
        auto ValidParts = 0;
        for (auto Part : _Monster.Get_Parts())
        {
            if (ck::IsValid(Part))
            { ++ValidParts; }
        }

        const auto Extra = f"validParts={ValidParts}";
        Log_Row("PartsRegisterOnBothMachines", Extra);
        Assert_Equals_Int(_Monster.Get_Parts().Num(), k_PartCount, f"the {Get_MachineName()}'s roster lists two parts");
        Assert_Equals_Int(ValidParts, k_PartCount, f"both of the {Get_MachineName()}'s parts are valid");
        Assert_Equals_Int(_Monster.Get_AttachedPartCount(), k_PartCount, f"both of the {Get_MachineName()}'s parts are attached");
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }
}
