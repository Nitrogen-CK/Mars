// Prey stands 110 ahead of a Pickle Mimic: on the server it stands and bites, its first four phases Windup, Active,
// Recover, None, landing a blow; the client's copy raises the same phases in order from the ledger, its lid gaping
// through the windup and shut through the recovery on its own clock, and raises no OnBlowLanded.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_ABiteRunsItsPhasesOnBothMachines
class UCk_AutoTest_Net_PickleMimic_ABiteRunsItsPhasesOnBothMachines : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(613000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(110.0, 0.0, 0.0);
    private const float32 k_BittenPreyHealth = 80.0f;
    private const float32 k_GapedInWindup = 0.6f;
    private const float32 k_ShutInRecover = 0.05f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMimic(Make_RowSpec());
        WaitUntil(n"Is_MimicSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MimicBiteEnded", n"OnServerBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Phases = Describe_MimicPhases();
        Assert_True(_MimicPhases.Num() >= 4, f"the server recorded four phases ({Phases})");
        if (_MimicPhases.Num() >= 4)
        {
            Assert_True(_MimicPhases[0].Phase == EMars_PickleMimic_ActionPhase::Windup && _MimicPhases[1].Phase == EMars_PickleMimic_ActionPhase::Active
                && _MimicPhases[2].Phase == EMars_PickleMimic_ActionPhase::Recover && _MimicPhases[3].Phase == EMars_PickleMimic_ActionPhase::None,
                f"the server's bite ran Windup, Active, Recover, None ({Phases})");
        }

        Assert_True(_MimicBlows >= 1, f"the server's bite landed a blow ({_MimicBlows})");
        const auto PreyHealth = _PreyHealth.Get_Current();
        Assert_True(PreyHealth <= k_BittenPreyHealth, f"the prey's Health is at most 80 (reads {PreyHealth})");
        Hold_MimicServerRow("ABiteRunsItsPhasesOnBothMachines", f"prey={PreyHealth}");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MimicBiteEnded", n"OnClientBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Phases = Describe_MimicPhases();
        Assert_True(_MimicPhases[0].Phase == EMars_PickleMimic_ActionPhase::Windup, f"the client's first phase is Windup ({Phases})");
        Assert_True(Get_AreMimicPhasesInOrder(), f"the client's phases are in order ({Phases})");
        Assert_True(_MimicWidestInWindup > k_GapedInWindup, f"the client's lid gaped above 0.6 in the windup ({_MimicWidestInWindup})");
        Assert_True(_MimicLowestInRecover < k_ShutInRecover, f"the client's lid was under 0.05 in the recovery ({_MimicLowestInRecover})");
        Assert_Equals_Int(_MimicBlows, 0, "the client's copy raised no OnBlowLanded");
        Finish_MimicRow("ABiteRunsItsPhasesOnBothMachines", "");
    }
}
