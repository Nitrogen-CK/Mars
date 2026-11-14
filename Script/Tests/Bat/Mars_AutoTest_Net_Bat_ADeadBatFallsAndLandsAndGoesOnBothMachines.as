// A roosting Cellar Bat whose corpse lasts 3 s takes a lethal blow on the server: there it falls (its body zone and its
// crowd agent off, its claim Released, the roost Free with one release) and lands on the floor; then its entity is
// gone. The client, which lays no floor, sees its copy die once (OnDied), turn its body zone off, show Falling then
// Landed (Landed once) and come to rest where the server's did, on the floor under the hang point without ever going
// under it; then its copy is gone too.
// Surface: Ck.Bat.Net.AS_Bat_ADeadBatFallsAndLandsAndGoesOnBothMachines
class UCk_AutoTest_Net_Bat_ADeadBatFallsAndLandsAndGoesOnBothMachines : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(666000.0, 0.0, 5000.0);
    private const float32 k_CorpseLasts = 3.0f;
    private const float32 k_LethalBlow = 1000.0f;

    // What this machine's copy read once it landed (the log line is written once it is gone).
    private FString _AtLanded = "";
    private int32 _LandedFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);
        _WithVisuals = true;
        _Spec.Monster.CorpseSeconds = k_CorpseLasts;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatDead", n"OnClientDead", k_SlowPolls);
            return;
        }

        Begin_ServerWorld(n"OnServerReady");
    }

    private TArray<EMars_Bat_Phase> Get_FallOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Falling);
        Order.Add(EMars_Bat_Phase::Landed);
        return Order;
    }

    private FString Describe_AtLanded()
    {
        const auto Location = _Bat.Get_Location();
        return f"atLanded=[frame {_LandedFrame} height {Location.Z - _Floor.Z} ground {FVector(Location.X - _HangAt.X, Location.Y - _HangAt.Y, 0.0).Size()} zoneEnabled {_Zone.Get_IsEnabled()} died {_BatDied}]";
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
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_LethalBlow, GameplayTags::DamageType_Mars_Blunt)));
        WaitUntil(n"Is_DeadAndLanded", n"OnServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LandedFrame = int32(utils_time::Get_FrameCounter());
        _AtLanded = Describe_AtLanded();
        const auto Height = _Bat.Get_Location().Z - _Floor.Z;
        const auto Roost = utils_bat::Get_RoostState(_Roost);
        Assert_False(_Zone.Get_IsEnabled(), "the server's body zone is off");
        Assert_False(utils_crowd_agent::Get_IsEnabled(_Bat.Get_Agent()), "the server's crowd agent left the crowd");
        Assert_True(Get_SawPhasesInOrder(Get_FallOrder()), f"the server recorded Falling then Landed (saw {Describe_BatPhases()})");
        Assert_True(Math::Abs(Height) <= 30.0, f"the server's bat rests on the floor ({Height} over it)");
        Assert_True(_Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Released, "the server's claim reads Released");
        Assert_True(Roost.Occupancy == EMars_BatRoost_Occupancy::Free, "the server's roost is free");
        Assert_Equals_Int(Roost.ReleaseCount, 1, "the server's roost was released once");
        WaitUntil(n"Is_BatGone", n"OnServerGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(2.0f, n"OnServerAfterGone");
    }

    UFUNCTION()
    private void OnServerAfterGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(utils_bat::Get_RoostState(_Roost).ReleaseCount, 1, "the server's roost was still released once");
        Hold_BatServerRow("ADeadBatFallsAndLandsAndGoesOnBothMachines", _AtLanded);
    }

    UFUNCTION()
    private void Is_CopyLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_Phase() == EMars_Bat_Phase::Landed);
    }

    UFUNCTION()
    private void OnClientDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CopyLanded", n"OnClientLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LandedFrame = int32(utils_time::Get_FrameCounter());
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        {
            Log_BatRow("ADeadBatFallsAndLandsAndGoesOnBothMachines", "gone before the settle ended");
            FinishFailure("the client's copy was gone before its settle ended");
            return;
        }

        _AtLanded = Describe_AtLanded();
        const auto Location = _Bat.Get_Location();
        const auto Height = Location.Z - _Floor.Z;
        const auto Ground = FVector(Location.X - _HangAt.X, Location.Y - _HangAt.Y, 0.0).Size();
        Assert_Equals_Int(_BatDied, 1, "the client raised OnDied exactly once");
        Assert_False(_Zone.Get_IsEnabled(), "the client's body zone is off");
        Assert_True(Get_SawPhasesInOrder(Get_FallOrder()), f"the client recorded Falling then Landed (saw {Describe_BatPhases()})");
        Assert_Equals_Int(Count_PhaseArrivals(EMars_Bat_Phase::Landed), 1, "the client recorded Landed once");
        Assert_True(Math::Abs(Height) <= 40.0, f"the client's copy rests within 40 of the floor ({Height} over it)");
        Assert_True(Ground <= 30.0, f"the client's copy rests within 30 of the hang point along the ground (reads {Ground})");
        Assert_True(_BatLowestHeight >= -5.0, f"the client's copy never went more than 5 under the floor (lowest {_BatLowestHeight})");
        Assert_False(ck::IsValid(_Bat.Get_Agent()), "the client's copy has no agent");
        WaitUntil(n"Is_BatGone", n"OnClientGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Finish_BatRow("ADeadBatFallsAndLandsAndGoesOnBothMachines", _AtLanded);
    }
}
