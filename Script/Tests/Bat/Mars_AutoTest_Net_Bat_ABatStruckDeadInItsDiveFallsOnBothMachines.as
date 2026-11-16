// A Cellar Bat with a 20 body dives slowly (250 a second, a dive of more than a second) at prey on the server; once the
// client's copy shows the dive, the client claims one cleaver blow on its copy's body zone. The authority applies it:
// the blow is lethal, the swoop ends once (Died, or Interrupted when the bat's own hit is drained before the death
// latches; the line says which), the dive deals nothing, and the bat falls from where it was hit and lands on the floor
// (its body zone and its crowd agent off, the roost Free with one release). The client's copy dies once, shows
// Swooping, Falling and Landed in that order, its shown stage going from the dive to None, rests on the floor under
// where it was hit without going through it, and raises no swoop or target signal.
// Surface: Ck.Bat.Net.AS_Bat_ABatStruckDeadInItsDiveFallsOnBothMachines
class UCk_AutoTest_Net_Bat_ABatStruckDeadInItsDiveFallsOnBothMachines : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(698000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(600.0, 0.0, 0.0);
    // 150 to the side of the strike point, off the dive's line.
    private const FVector k_HandFromFloor = FVector(330.0, 150.0, 250.0);

    private int32 _ClaimFrame = -1;
    private FVector _ClaimedAt = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatStrikeRowAt(k_Floor, k_HandFromFloor);
        _Spec.Swoop.Timing.CooldownSeconds = 30.0f;
        _Spec.Swoop.Timing.SwoopSeconds = 4.0f;
        _Spec.Flight.SwoopSpeed = 250.0f;
        _Spec.Monster.BodyHealth = FMars_Health_Spec(20.0f);
        _Spec.Monster.CorpseSeconds = 8.0f;
        _FacingPoint = TOptional<FVector>(Get_PreyPlace(k_PreyOffset));

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimTheBat", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    private TArray<EMars_Bat_Phase> Get_DeathOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Swooping);
        Order.Add(EMars_Bat_Phase::Falling);
        Order.Add(EMars_Bat_Phase::Landed);
        return Order;
    }

    private int32 Get_FirstFrameOf(EMars_Bat_Phase InPhase) const
    {
        for (const auto& Recorded : _BatPhases)
        {
            if (Recorded.To == InPhase)
            { return Recorded.Frame; }
        }

        return -1;
    }

    // Whether Stunned was recorded before Falling.
    private bool Get_WasStunnedBeforeFalling() const
    {
        const auto Stunned = Get_FirstFrameOf(EMars_Bat_Phase::Stunned);
        const auto Falling = Get_FirstFrameOf(EMars_Bat_Phase::Falling);
        return Stunned >= 0 && (Falling < 0 || Stunned <= Falling);
    }

    private FString Describe_Death()
    {
        const auto Tally = Get_Tally();
        return f"claimFrame={_ClaimFrame} claimedAt={_ClaimedAt.ToString()} fallingFrame={Get_FirstFrameOf(EMars_Bat_Phase::Falling)} landedFrame={Get_FirstFrameOf(EMars_Bat_Phase::Landed)} stunnedBeforeFalling={Get_WasStunnedBeforeFalling()} tally={Tally.Applied}/{Tally.Refused}";
    }

    UFUNCTION()
    private void Is_DeadAndLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_IsDead() && _Bat.Get_Phase() == EMars_Bat_Phase::Landed);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Arm_Server();
        WaitUntil(n"Is_Armed", n"OnServerArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ServerWorld(n"OnServerBatReady");
    }

    UFUNCTION()
    private void OnServerBatReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_DeadAndLanded", n"OnServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BatRow("ABatStruckDeadInItsDiveFallsOnBothMachines", Describe_Death());
        const auto Height = _Bat.Get_Location().Z - _Floor.Z;
        const auto Roost = utils_bat::Get_RoostState(_Roost);
        const auto IsDiedOrInterrupted = _BatCancelReasons.Num() == 1
            && (_BatCancelReasons[0] == EMars_Bat_SwoopCancel::Died || _BatCancelReasons[0] == EMars_Bat_SwoopCancel::Interrupted);
        Assert_Tally(1, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_Equals_Int(_BatSwoopsCancelled, 1, "the server raised OnSwoopCancelled exactly once");
        Assert_True(IsDiedOrInterrupted, "the server's swoop was cancelled Died or Interrupted");
        Assert_Equals_Int(_BatSwoopsLanded, 0, "the server raised no OnSwoopLanded");
        Assert_Equals_Int(_PreyDamaged, 0, "the prey was not damaged");
        Assert_True(Math::IsNearlyEqual(_PreyHealth.Get_Current(), 100.0f, 0.01f), "the prey's Health reads 100");
        Assert_True(Get_SawPhasesInOrder(Get_DeathOrder()), f"the server recorded Swooping, Falling, Landed (saw {Describe_BatPhases()})");
        Assert_True(_Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::None, "the server's swoop stage reads None");
        Assert_False(_Zone.Get_IsEnabled(), "the server's body zone is off");
        Assert_False(utils_crowd_agent::Get_IsEnabled(_Bat.Get_Agent()), "the server's crowd agent left the crowd");
        Assert_True(Math::Abs(Height) <= 30.0, f"the server's bat rests on the floor ({Height} over it)");
        Assert_True(Roost.Occupancy == EMars_BatRoost_Occupancy::Free, "the server's roost is free");
        Assert_Equals_Int(Roost.ReleaseCount, 1, "the server's roost was released once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void Is_ClientReadyToClaimTheBat(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && Get_IsArmed() && Get_IsBatFound());
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CopyDiving", n"OnClientDiving", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_CopyDiving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::Committed);
    }

    // At once: the client's copy's body zone, the cleaver, a contact at its copy's root, +X.
    UFUNCTION()
    private void OnClientDiving(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Address = _Zone.Get_Address();
        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(mars_items::Cleaver());
        Claim.Location = _Bat.Get_Location();
        Claim.Normal = FVector(-1.0, 0.0, 0.0);
        Claim.Impulse = FVector::ForwardVector;
        _ClaimFrame = int32(utils_time::Get_FrameCounter());
        _ClaimedAt = Claim.Location;
        Fire_Claim(Claim);
        WaitUntil(n"Is_DeadAndLanded", n"OnClientLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        Log_BatRow("ABatStruckDeadInItsDiveFallsOnBothMachines", Describe_Death());
        const auto Height = _Bat.Get_Location().Z - _Floor.Z;
        auto Stages = TArray<EMars_Bat_SwoopStage>();
        Stages.Add(EMars_Bat_SwoopStage::Telegraphing);
        Stages.Add(EMars_Bat_SwoopStage::Committed);
        Assert_Equals_Int(_BatDied, 1, "the client raised OnDied exactly once");
        Assert_Equals_Int(_BatDamaged, 1, "the client's copy's body Health raised OnDamaged exactly once");
        Assert_True(_Health.Get_IsDepleted(), "the client's copy's body Health is depleted");
        Assert_True(Get_SawPhasesInOrder(Get_DeathOrder()), f"the client recorded Swooping, Falling, Landed (saw {Describe_BatPhases()})");
        Assert_Equals_Int(Count_PhaseArrivals(EMars_Bat_Phase::Landed), 1, "the client recorded Landed once");
        Assert_True(Get_SampledStagesInOrder(Stages), f"the client sampled Telegraphing then Committed (sampled {Describe_Stages()})");
        Assert_True(Get_LastSampledStage() == EMars_Bat_SwoopStage::None,
            f"the client's last sampled stage reads None (reads {Get_LastSampledStage() :n})");
        Assert_False(_Zone.Get_IsEnabled(), "the client's body zone is off");
        Assert_True(Math::Abs(Height) <= 40.0, f"the client's copy rests within 40 of the floor ({Height} over it)");
        Assert_True(_BatLowestHeight >= -5.0, f"the client's copy never went more than 5 under the floor (lowest {_BatLowestHeight})");
        Assert_CopyKeepsNoSwoopOfItsOwn();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
