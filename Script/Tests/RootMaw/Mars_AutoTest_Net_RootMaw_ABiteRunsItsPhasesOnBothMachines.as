// Prey stands 110 ahead of a Root Maw: on the server it rises and bites, its first four phases Windup, Active, Recover,
// None, landing a blow; the client's copy raises the same phases in order from the ledger, its jaw gaping through the
// windup and shut through the recovery on its own clock, and raises no OnBlowLanded.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ABiteRunsItsPhasesOnBothMachines
class UCk_AutoTest_Net_RootMaw_ABiteRunsItsPhasesOnBothMachines : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(580000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(110.0, 0.0, 0.0);
    private const float32 k_BittenPreyHealth = 78.0f;
    private const float32 k_GapedInWindup = 0.6f;
    private const float32 k_ShutInRecover = 0.05f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(FMars_RootMaw_Spec());
        WaitUntil(n"Is_MawStanding", n"OnServerGrounded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGrounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MawBiteEnded", n"OnServerBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Phases = Describe_MawPhases();
        Assert_True(_MawPhases.Num() >= 4, f"the server recorded four phases ({Phases})");
        if (_MawPhases.Num() >= 4)
        {
            Assert_True(_MawPhases[0].Phase == EMars_RootMaw_ActionPhase::Windup && _MawPhases[1].Phase == EMars_RootMaw_ActionPhase::Active
                && _MawPhases[2].Phase == EMars_RootMaw_ActionPhase::Recover && _MawPhases[3].Phase == EMars_RootMaw_ActionPhase::None,
                f"the server's bite ran Windup, Active, Recover, None ({Phases})");
        }

        Assert_True(_MawBlows >= 1, f"the server's bite landed a blow ({_MawBlows})");
        const auto PreyHealth = _PreyHealth.Get_Current();
        Assert_True(PreyHealth <= k_BittenPreyHealth, f"the prey's Health is at most 78 (reads {PreyHealth})");
        Hold_MawServerRow("ABiteRunsItsPhasesOnBothMachines", f"prey={PreyHealth}");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MawBiteEnded", n"OnClientBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Phases = Describe_MawPhases();
        Assert_True(_MawPhases[0].Phase == EMars_RootMaw_ActionPhase::Windup, f"the client's first phase is Windup ({Phases})");
        Assert_True(Get_AreMawPhasesInOrder(), f"the client's phases are in order ({Phases})");
        Assert_True(_MawWidestInWindup > k_GapedInWindup, f"the client's jaw gaped above 0.6 in the windup ({_MawWidestInWindup})");
        Assert_True(_MawLowestInRecover < k_ShutInRecover, f"the client's jaw was under 0.05 in the recovery ({_MawLowestInRecover})");
        Assert_Equals_Int(_MawBlows, 0, "the client's copy raised no OnBlowLanded");
        Finish_MawRow("ABiteRunsItsPhasesOnBothMachines", "");
    }
}
