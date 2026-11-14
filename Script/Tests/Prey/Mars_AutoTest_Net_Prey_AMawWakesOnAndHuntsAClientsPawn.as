// A Root Maw hunts a joined player: buried 400 from a pawn nobody controls, it holds no target and stays down; once the
// client's controller possesses the pawn, the server's copy of the pawn carries TAG_MarsSharedCombatTarget only, the
// Maw takes it as its target, bursts up and glides to it. The client's copy of the Maw rises once (OnStance(Emerged)
// exactly once) and follows the replicated root to within 200 of the client's pawn, which carries neither tag there.
// The controller gets its old pawn back only after the client has asserted.
// Surface: Ck.Prey.Net.AS_Prey_AMawWakesOnAndHuntsAClientsPawn
class UCk_AutoTest_Net_Prey_AMawWakesOnAndHuntsAClientsPawn : UMars_AutoTestRig_NetPrey
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(591000.0, 0.0, 5000.0);
    private const FVector k_MawOffset = FVector(-400.0, 0.0, 0.0);
    private const float64 k_ReachedCm = 200.0;
    private const float64 k_TravelledCm = 150.0;
    // One bite at most in the row.
    private const float32 k_BiteCooldownSeconds = 30.0f;
    private const FString k_Row = "AMawWakesOnAndHuntsAClientsPawn";

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
        Assert_True(_Maw.Get_IsBuried(), "the server's Maw stays buried beside a pawn nobody controls");
        Assert_False(_Maw.Get_HasTarget(), "the server's Maw holds no target before the possession");
        Assert_False(Get_HasSharedTag(_Player) || Get_HasLocalTag(_Player), "the server's pawn carries neither tag before the possession");
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_PreyRow(k_Row, "remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        _PossessFrame = int32(utils_time::Get_FrameCounter());
        WaitUntil(n"Is_MawEmerged", n"OnServerEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsTargetThePawn(), "the server's Maw targets the pawn's entity once it reads emerged");
        Assert_True(Get_HasSharedTag(_Player), "the server's pawn carries TAG_MarsSharedCombatTarget once the client controls it");
        Assert_False(Get_HasLocalTag(_Player), "the server's pawn carries no TAG_MarsCombatTarget (the host does not control it)");
        WaitUntil(n"Is_MawNearPawn", n"OnServerReached", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReached(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSampling(k_SettleSeconds * 2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PreyRow(k_Row, f"possessFrame={_PossessFrame}");
        Assert_Equals_Int(_MawEmergedStances, 1, "the server raised OnStance(Emerged) once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Both
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_MawNearPawn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Prey();
        const auto Distance = Get_MawToPawn();
        auto Result = OutResult;
        Result.Set(Distance >= 0.0 && Distance <= k_ReachedCm);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientControlledAndEmerged", n"OnClientEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientControlledAndEmerged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Prey();
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && _Pawn.IsLocallyControlled() && Get_IsMawGone() == false && _Maw.Get_IsEmerged());
    }

    UFUNCTION()
    private void OnClientEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MawNearPawn", n"OnClientReached", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientReached(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Travelled = (_Maw.Get_Location() - _MawFoundAt).Size();
        const auto ToPawn = Get_MawToPawn();
        Log_PreyRow(k_Row, f"travelled={Travelled}");
        Assert_True(_MawStanceWhenFound == EMars_RootMaw_Stance::Buried, "the client found its copy of the Maw buried");
        Assert_True(Math::IsNearlyEqual(_Maw.Get_Emerge(), 1.0f, 0.0001f), "the client's Maw is fully up");
        Assert_Equals_Int(_MawEmergedStances, 1, "the client raised OnStance(Emerged) exactly once");
        Assert_True(Travelled > k_TravelledCm, f"the client's Maw moved more than 150 from where it was found (moved {Travelled})");
        Assert_True(ToPawn >= 0.0 && ToPawn <= k_ReachedCm, f"the client's Maw is within 200 of its pawn (reads {ToPawn})");
        Assert_False(Get_HasSharedTag(_Player) || Get_HasLocalTag(_Player), "the client's pawn carries neither tag");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown();
        FinishSuccess();
    }
}
