// A remote player is downed by a hit the server lands and revived by a heal the server applies: with the pawn possessed by
// the client's controller, 100 Blunt on the server's copy depletes the Health; the client's copy reads it from the ledger
// and its state machine (the owning copy decides) enters Downed once, which the server's copy follows; a heal to the max
// brings the client back to 100 and Alive, and the server's copy follows again. The client's copy raises OnDepleted and
// OnHealed once each. The controller gets its old pawn back only after the client has asserted.
// Surface: Ck.PlayerCombat.Net.AS_PlayerCombat_ARemotePlayerIsDownedAndRevived
class UCk_AutoTest_Net_PlayerCombat_ARemotePlayerIsDownedAndRevived : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(533000.0, 0.0, 5000.0);
    private const FString k_Row = "ARemotePlayerIsDownedAndRevived";

    // Frame counters (one counter for both PIE worlds) of the steps this machine saw; -1 before.
    private int32 _HitFrame = -1;
    private int32 _ServerDownedFrame = -1;
    private int32 _HealFrame = -1;
    private int32 _ServerAliveFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer())
        { Spawn_ServerPawn(); }

        WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        if (Get_IsServer())
        {
            WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
            return;
        }

        WaitUntil(n"Is_ClientControlledAndAlive", n"OnClientAlive", k_SlowPolls);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_Row(k_Row, "remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        WaitUntil(n"Is_InAlive", n"OnServerSeesAlive", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_InAlive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Alive));
    }

    UFUNCTION()
    private void Is_InDowned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Downed));
    }

    UFUNCTION()
    private void OnServerSeesAlive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _HitFrame = int32(utils_time::Get_FrameCounter());
        Request_ZoneHit(100.0f, GameplayTags::DamageType_Mars_Blunt);
        WaitUntil(n"Is_InDowned", n"OnServerSeesDowned", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeesDowned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ServerDownedFrame = int32(utils_time::Get_FrameCounter());
        _HealFrame = _ServerDownedFrame;
        _Health.Request_Heal(FMars_Request_Health_Heal(_Health.Get_Max()));
        WaitUntil(n"Is_InAlive", n"OnServerSeesRevived", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeesRevived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ServerAliveFrame = int32(utils_time::Get_FrameCounter());
        const auto Frames = f"hitFrame={_HitFrame} serverDownedFrame={_ServerDownedFrame} healFrame={_HealFrame} serverAliveFrame={_ServerAliveFrame}";
        Log_Row(k_Row, Frames);
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the server's copy reads 100 again");
        Assert_False(_Health.Get_IsDepleted(), "the server's copy is not depleted");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserts first: handing the pawn back makes its copy a non-owning one, which replays the history.
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientControlledAndAlive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Pawn.IsLocallyControlled() && Get_IsInState(UMars_SmState_Alive));
    }

    UFUNCTION()
    private void OnClientAlive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientDowned", n"OnClientDowned", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientDowned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_DownedEntries > 0 && _Health.Get_IsDepleted());
    }

    UFUNCTION()
    private void OnClientDowned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientRevived", n"OnClientRevived", k_SlowPolls);
    }

    // Downed was entered and Alive stands again, with the Health back at 100.
    UFUNCTION()
    private void Is_ClientRevived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_DownedEntries > 0 && Get_IsInState(UMars_SmState_Alive) && Get_IsCurrent(100.0f) && _Health.Get_IsDepleted() == false);
    }

    UFUNCTION()
    private void OnClientRevived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Frames = f"clientDownedFrame={_DownedFrame} clientAliveFrame={_AliveFrame}";
        Log_Row(k_Row, Frames);
        Assert_Equals_Int(_DownedEntries, 1, "the client's state machine entered Downed once");
        Assert_True(Get_IsInState(UMars_SmState_Alive), "the client's state machine is in Alive again");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the client's copy reads 100");
        Assert_False(_Health.Get_IsDepleted(), "the client's copy is not depleted");
        Assert_Equals_Int(_Depleted, 1, "the client's copy raised OnDepleted once");
        Assert_Equals_Int(_Healed, 1, "the client's copy raised OnHealed once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown();
        FinishSuccess();
    }
}
