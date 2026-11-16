// A joined player stands 600 from a roosting Cellar Bat: the server spawns the production pawn there, nobody's, and the
// bat holds no target; once the client's controller possesses it, the server's copy of the pawn carries
// TAG_MarsSharedCombatTarget only, the bat takes it as its target, swoops and lands one blow on the pawn's capsule. The
// pawn's Health reads 88 on both machines, each raising OnDamaged once with 12 applied. The client's copy of the bat
// shows the dive; the pawn carries neither tag there. The controller gets its old pawn back only after the client has
// asserted.
// Surface: Ck.Bat.Net.AS_Bat_ASwoopHurtsAJoinedPlayerOnBothMachines
class UCk_AutoTest_Net_Bat_ASwoopHurtsAJoinedPlayerOnBothMachines : UMars_AutoTestRig_NetBatPawn
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(695000.0, 0.0, 5000.0);
    private const FVector k_PawnOffset = FVector(600.0, 0.0, 0.0);
    // The aim point 90 over the floor, inside the capsule, where the stand-in's is.
    private const float32 k_AimHeight = 15.0f;
    private const float32 k_HurtHealth = 88.0f;
    private const float32 k_BlowDamage = 12.0f;
    private const FString k_Row = "ASwoopHurtsAJoinedPlayerOnBothMachines";

    private int32 _PossessFrame = -1;
    private int32 _LandedFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatPawnRow(k_Floor, k_PawnOffset);
        _Spec.Swoop.Timing.CooldownSeconds = 30.0f;
        _Spec.Swoop.AimHeight = k_AimHeight;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerWorld(n"OnServerReady");
    }

    private FString Describe_Frames() const
    {
        return f"possessFrame={_PossessFrame} landedFrame={_LandedFrame}";
    }

    private bool Get_IsBlowPawnHurtOnce()
    {
        return Get_IsBlowPawnComposed() && Math::IsNearlyEqual(_BlowHealth.Get_Current(), k_HurtHealth, 0.01f)
            && _BlowApplied.Num() == 1 && Math::IsNearlyEqual(_BlowApplied[0], k_BlowDamage, 0.01f)
            && _BlowHealth.Get_IsDepleted() == false;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBlowPawn();
        WaitUntil(n"Is_BlowPawnComposed", n"OnServerPawnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPawnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the server's bat roosts beside a pawn nobody controls");
        Assert_False(ck::IsValid(_Bat.Get_Target()), "the server's bat holds no target before the possession");
        Assert_False(Get_BlowPawnHasTag(n"TAG_MarsSharedCombatTarget"), "the server's pawn carries no shared tag before the possession");
        if (Request_ServerPossessBlowPawn() == false)
        {
            Log_BatRow(k_Row, f"remoteController=none {Describe_BlowPawn()}");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        _PossessFrame = int32(utils_time::Get_FrameCounter());
        WaitUntil(n"Is_ServerLandedOnThePawn", n"OnServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLandedOnThePawn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        Sample_BlowTarget();
        if (_LandedFrame < 0 && _BatSwoopsLanded > 0)
        { _LandedFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _BatSwoopsLanded > 0 && _BlowApplied.Num() > 0);
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSampling(2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BatRow(k_Row, f"{Describe_Frames()} {Describe_BlowPawn()}");
        Assert_Equals_Int(_BatSwoopsLanded, 1, "the server raised OnSwoopLanded exactly once");
        Assert_True(_BatLandedZones.Num() == 1 && _BatLandedZones[0] == _BlowZone, "the server's blow landed on the pawn's zone");
        Assert_Equals_Int(_BatSwoopsCancelled, 0, "the server raised no OnSwoopCancelled");
        Assert_True(Get_IsBlowPawnHurtOnce(),
            f"the server's pawn reads 88, OnDamaged once with 12 applied (reads {_BlowHealth.Get_Current()}, {_BlowApplied.Num()} damaged)");
        Assert_True(Get_BlowPawnHasTag(n"TAG_MarsSharedCombatTarget"), "the server's pawn carries TAG_MarsSharedCombatTarget");
        Assert_False(Get_BlowPawnHasTag(n"TAG_MarsCombatTarget"), "the server's pawn carries no TAG_MarsCombatTarget (the host does not control it)");
        Assert_True(_BlowTargetFrame >= 0, "the server's bat took the pawn as its target");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerReturned");
    }

    UFUNCTION()
    private void OnServerReturned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TearDown_BlowPawn();
        FinishSuccess();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the client found its copy of the bat roosting");
        WaitUntil(n"Is_ClientPawnHurt", n"OnClientHurt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientPawnHurt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBlowPawnComposed() && _BlowPawn.IsLocallyControlled() && _BlowApplied.Num() > 0);
    }

    UFUNCTION()
    private void OnClientHurt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BatRow(k_Row, Describe_BlowPawn());
        auto Dive = TArray<EMars_Bat_SwoopStage>();
        Dive.Add(EMars_Bat_SwoopStage::Committed);
        Assert_True(Get_IsBlowPawnHurtOnce(),
            f"the client's pawn reads 88, OnDamaged once with 12 applied, not depleted (reads {_BlowHealth.Get_Current()}, {_BlowApplied.Num()} damaged)");
        Assert_False(Get_BlowPawnHasTag(n"TAG_MarsSharedCombatTarget") || Get_BlowPawnHasTag(n"TAG_MarsCombatTarget"),
            "the client's pawn carries neither tag");
        Assert_True(Count_PhaseArrivals(EMars_Bat_Phase::Swooping) > 0, f"the client's copy of the bat recorded Swooping (saw {Describe_BatPhases()})");
        Assert_True(Get_SampledStagesInOrder(Dive), f"the client's sampled stages hold Committed (sampled {Describe_Stages()})");
        Assert_CopyKeepsNoSwoopOfItsOwn();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_BlowPawn();
        FinishSuccess();
    }
}
