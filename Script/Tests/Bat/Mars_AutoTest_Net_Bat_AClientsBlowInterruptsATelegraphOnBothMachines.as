// A Cellar Bat telegraphs for 3 s at prey on the server; once the client's copy shows that telegraph a tenth of the
// way through, the client claims one cleaver blow on its copy's body zone. The authority applies it: the swoop ends
// Interrupted (OnSwoopCancelled once), the bat is stunned or flinches and never dives, and its body Health reads 20 on
// both machines. The client's copy shows that phase once, its shown stage going from the telegraph to None as it
// arrives, raises OnDamaged once and no swoop or target signal, and counts no hit of its own.
// Surface: Ck.Bat.Net.AS_Bat_AClientsBlowInterruptsATelegraphOnBothMachines
class UCk_AutoTest_Net_Bat_AClientsBlowInterruptsATelegraphOnBothMachines : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(697000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(600.0, 0.0, 0.0);
    // 150 to the side of the strike point, off the dive's line.
    private const FVector k_HandFromFloor = FVector(330.0, 150.0, 250.0);
    private const float32 k_StruckHealth = 20.0f;
    private const float32 k_ClaimAtProgress = 0.1f;

    private int32 _ClaimFrame = -1;
    private int32 _ReactionFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatStrikeRowAt(k_Floor, k_HandFromFloor);
        _Spec.Swoop.Timing.CooldownSeconds = 30.0f;
        _Spec.Swoop.Timing.TelegraphSeconds = 3.0f;
        _FacingPoint = TOptional<FVector>(Get_PreyPlace(k_PreyOffset));

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimTheBat", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    private int32 Count_Reactions() const
    {
        return Count_PhaseArrivals(EMars_Bat_Phase::Stunned) + Count_PhaseArrivals(EMars_Bat_Phase::Hit);
    }

    // The first frame a reaction was recorded; -1 before.
    private int32 Get_FirstReactionFrame() const
    {
        for (const auto& Recorded : _BatPhases)
        {
            if (Recorded.To == EMars_Bat_Phase::Stunned || Recorded.To == EMars_Bat_Phase::Hit)
            { return Recorded.Frame; }
        }

        return -1;
    }

    private FString Describe_Reaction()
    {
        const auto Tally = Get_Tally();
        return f"stunned={Count_PhaseArrivals(EMars_Bat_Phase::Stunned)} hit={Count_PhaseArrivals(EMars_Bat_Phase::Hit)} claimFrame={_ClaimFrame} reactionFrame={Get_FirstReactionFrame()} tally={Tally.Applied}/{Tally.Refused}";
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
        WaitUntil(n"Is_ServerHitAndReacted", n"OnServerStruck", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHitAndReacted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_Hurt().HitCount == 1 && Count_Reactions() > 0);
    }

    UFUNCTION()
    private void OnServerStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BatRow("AClientsBlowInterruptsATelegraphOnBothMachines", Describe_Reaction());
        Assert_Tally(1, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_Equals_Int(_BatSwoopsCancelled, 1, "the server raised OnSwoopCancelled exactly once");
        Assert_True(_BatCancelReasons.Num() == 1 && _BatCancelReasons[0] == EMars_Bat_SwoopCancel::Interrupted,
            "the server's swoop was cancelled Interrupted");
        Assert_Equals_Int(_BatSwoopsLanded, 0, "the server raised no OnSwoopLanded");
        Assert_Equals_Int(_PreyDamaged, 0, "the prey was not damaged");
        Assert_True(Math::IsNearlyEqual(_PreyHealth.Get_Current(), 100.0f, 0.01f), "the prey's Health reads 100");
        Assert_Equals_Int(Count_PhaseArrivals(EMars_Bat_Phase::Swooping), 0, "the server never recorded Swooping");
        Assert_True(_Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::None, "the server's swoop stage reads None");
        Assert_True(Get_IsCurrent(k_StruckHealth), f"the server's body Health reads 20 (reads {_Health.Get_Current()})");
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
        WaitUntil(n"Is_CopyTelegraphingPastTheClaimPoint", n"OnClientTelegraphing", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_CopyTelegraphingPastTheClaimPoint(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        if (Get_IsBatGone())
        { return; }

        const auto Frame = _Bat.Get_SwoopFrame();
        auto Result = OutResult;
        Result.Set(Frame.Stage == EMars_Bat_SwoopStage::Telegraphing && Frame.Alpha >= k_ClaimAtProgress);
    }

    // The client's copy's body zone, the cleaver, a contact at its copy's root, +X.
    UFUNCTION()
    private void OnClientTelegraphing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        Fire_Claim(Claim);
        WaitUntil(n"Is_CopyStruckAndReacted", n"OnClientStruck", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_CopyStruckAndReacted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && Get_IsCurrent(k_StruckHealth) && Count_Reactions() > 0);
    }

    UFUNCTION()
    private void OnClientStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        Log_BatRow("AClientsBlowInterruptsATelegraphOnBothMachines", Describe_Reaction());
        auto Expected = TArray<EMars_Bat_SwoopStage>();
        Expected.Add(EMars_Bat_SwoopStage::None);
        Expected.Add(EMars_Bat_SwoopStage::Telegraphing);
        Expected.Add(EMars_Bat_SwoopStage::None);
        const auto Frame = _Bat.Get_SwoopFrame();
        Assert_Equals_Int(_BatDamaged, 1, "the client's copy's body Health raised OnDamaged exactly once");
        Assert_Equals_Int(Count_Reactions(), 1, "the client recorded Stunned or Hit exactly once");
        Assert_Equals_Int(Count_PhaseArrivals(EMars_Bat_Phase::Swooping), 0, "the client never recorded Swooping");
        Assert_True(Get_SampledStagesAre(Expected), f"the client sampled None, Telegraphing, None (sampled {Describe_Stages()})");
        Assert_True(_BatSwoop.Telegraph.Highest >= k_ClaimAtProgress && _BatSwoop.Telegraph.Highest < 0.9f,
            f"the client's telegraph progress reached the claim's 0.1 and stopped short of 0.9 (highest {_BatSwoop.Telegraph.Highest})");
        Assert_Equals_Int(_BatSwoop.Rewinds, 0, "the client's stage clock never rewound");
        Assert_True(Frame.Stage == EMars_Bat_SwoopStage::None, f"the client's swoop stage reads None (reads {Frame.Stage :n})");
        Assert_True(Frame.Alpha == 0.0f, f"the client's swoop progress reads 0 (reads {Frame.Alpha})");
        Assert_Equals_Int(_Bat.Get_Hurt().HitCount, 0, "the client's copy counts no hit of its own");
        Assert_CopyKeepsNoSwoopOfItsOwn();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
