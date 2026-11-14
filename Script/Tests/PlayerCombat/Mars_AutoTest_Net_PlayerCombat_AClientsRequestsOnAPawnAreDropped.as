// A client that hits its copy of a pawn's zone and asks its copy's Health for damage changes nothing: both are dropped
// where they are made (the client has no authority over the pawn), so both machines read 100, the server's ledger
// counts nothing and the client's copy raises no signal.
// Surface: Ck.PlayerCombat.Net.AS_PlayerCombat_AClientsRequestsOnAPawnAreDropped
class UCk_AutoTest_Net_PlayerCombat_AClientsRequestsOnAPawnAreDropped : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(532000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const FString k_Row = "AClientsRequestsOnAPawnAreDropped";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        if (Get_IsServer())
        {
            WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
            return;
        }

        Request_ZoneHit(30.0f, GameplayTags::DamageType_Mars_Blunt);
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(30.0f, GameplayTags::DamageType_Mars_Blunt)));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_Ledger();
        Log_Row(k_Row, "");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the server's copy reads 100");
        Assert_True(Ledger.DamageSerial == 0 && Ledger.HealSerial == 0 && Ledger.DepletionSerial == 0,
            f"the server's ledger counts nothing (d{Ledger.DamageSerial} h{Ledger.HealSerial} x{Ledger.DepletionSerial})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The watch is the server's hold: it wrote nothing after the spawn.
        TearDown();
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row(k_Row, "");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the client's copy reads 100");
        Assert_True(_Damaged.Num() == 0 && _Healed == 0 && _Depleted == 0, "the client's copy raised no signal");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown();
        FinishSuccess();
    }
}
