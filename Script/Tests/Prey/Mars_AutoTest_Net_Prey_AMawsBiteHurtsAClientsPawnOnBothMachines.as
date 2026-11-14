// A Root Maw bites a joined player: buried 110 from a pawn nobody controls, it holds no target (a pawn in its reach is
// not prey until a player controls it); once the client's controller possesses the pawn, it bursts up and bites once.
// The blow lands on the server's copy (Health 78, OnDamaged once) and reaches the client's copy through the Health's
// ledger: OnDamaged exactly once with 22 applied, 78, not depleted, the state machine never Downed; the client's Maw
// raised the bite's phases in order. The bite cools down for longer than the row, so one bite at most lands. The
// controller gets its old pawn back only after the client has asserted.
// Surface: Ck.Prey.Net.AS_Prey_AMawsBiteHurtsAClientsPawnOnBothMachines
class UCk_AutoTest_Net_Prey_AMawsBiteHurtsAClientsPawnOnBothMachines : UMars_AutoTestRig_NetPrey
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(592000.0, 0.0, 5000.0);
    private const FVector k_MawOffset = FVector(-110.0, 0.0, 0.0);
    private const float32 k_BiteCooldownSeconds = 30.0f;
    private const float32 k_Bitten = 78.0f;
    private const float32 k_BiteDamage = 22.0f;
    private const FString k_Row = "AMawsBiteHurtsAClientsPawnOnBothMachines";

    private int32 _PossessFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PreyRow(k_Base, k_MawOffset);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        WaitUntil(n"Is_ServerReadyForMaw", n"OnServerReadyForMaw", k_SlowPolls);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerReadyForMaw(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        auto Spec = FMars_RootMaw_Spec();
        Spec.Bite.Timing.CooldownSeconds = k_BiteCooldownSeconds;
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(k_MawOffset, Spec);
        WaitUntil(n"Is_MawStanding", n"OnServerGrounded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGrounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_MawStandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Maw.Get_IsBuried(), "the server's Maw stays buried with a pawn nobody controls in its reach");
        Assert_False(_Maw.Get_HasTarget(), "the server's Maw holds no target before the possession");
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_PreyRow(k_Row, "remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        _PossessFrame = int32(utils_time::Get_FrameCounter());
        WaitUntil(n"Is_BittenAndBiteEnded", n"OnServerBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSampling(k_SettleSeconds * 2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PreyRow(k_Row, f"possessFrame={_PossessFrame}");
        Assert_True(Get_IsCurrent(k_Bitten), f"the server's pawn still reads 78 (reads {_Health.Get_Current()})");
        Assert_Equals_Int(_Damaged.Num(), 1, "the server's pawn Health raised OnDamaged once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Both
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_BittenAndBiteEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Prey();
        auto Result = OutResult;
        Result.Set(Get_IsReceiverFound() && Get_IsCurrent(k_Bitten) && Get_HasMawBiteEnded());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_BittenAndBiteEnded", n"OnClientBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PreyRow(k_Row, "");
        const auto Applied = _Damaged.Num() > 0 ? _Damaged[0] : -1.0f;
        Assert_True(_MawStanceWhenFound == EMars_RootMaw_Stance::Buried, "the client found its copy of the Maw buried");
        Assert_Equals_Int(_Damaged.Num(), 1, "the client's pawn Health raised OnDamaged exactly once");
        Assert_Equals_Float(Applied, k_BiteDamage, 0.01f, "the client's OnDamaged applied 22");
        Assert_True(Get_IsCurrent(k_Bitten), f"the client's pawn reads 78 (reads {_Health.Get_Current()})");
        Assert_False(_Health.Get_IsDepleted(), "the client's pawn is not depleted");
        Assert_True(_MawPhases.Num() > 0 && _MawPhases[0].Phase == EMars_RootMaw_ActionPhase::Windup,
            f"the client's Maw raised Windup first (phases {Describe_MawPhases()})");
        Assert_True(Get_HasMawActiveBeforeEnd(), "the client's Maw raised an Active before the None");
        Assert_Equals_Int(_DownedEntries, 0, "the client's state machine never entered Downed");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown();
        FinishSuccess();
    }
}
