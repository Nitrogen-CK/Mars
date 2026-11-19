// A client in the production pawn asks for a station (the station net rows' bare test station) through its Act cue, as
// the station's Use interaction does. On both machines the station names the client's player and the player's back-ref
// names the station, and that machine's copy of the player's state machine has left Locomotion for Operating.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientOperatesAStationOnBothMachines
class UCk_AutoTest_Net_RealPawn_AClientOperatesAStationOnBothMachines : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(914000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientOperatesAStationOnBothMachines";
    private const FVector k_StationFromBase = FVector(150.0, 0.0, 0.0);

    private FCk_Handle_Station _Station;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientOwnerReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnServerComposed", k_SlowPolls);
    }

    // Both ends of the link name each other, and this machine's copy of the player's state machine is in Operating.
    private bool Get_IsOperatingHere()
    {
        return Get_IsStationFound() && Get_IsLinked() && Get_IsStateActive(UMars_SmState_Operating);
    }

    private bool Get_IsLinked()
    {
        const auto Operator = _Player.As_Operator(ECk_SanityCheck::UnChecked);
        return ck::IsValid(_Station) && ck::IsValid(Operator) && _Station.Get_IsOperatedBy(Operator) && Operator.Get_Station() == _Station;
    }

    private bool Get_IsStationFound()
    {
        if (ck::IsValid(_Station))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetStation"))
        {
            auto Station = Candidate.As_Station(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Station))
            { continue; }

            _Station = Station;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    private void Assert_Operating()
    {
        const auto Machine = Get_MachineName();
        const auto States = Describe_ActiveStates();
        Log_RealPawnRow(k_Row, f"station={ck::IsValid(_Station)} linked={Get_IsLinked()}");
        Assert_True(ck::IsValid(_Station), f"the {Machine} has its copy of the station");
        Assert_True(Get_IsLinked(), f"the {Machine}'s station names the client's player and the player's back-ref names it");
        Assert_True(Get_IsStateActive(UMars_SmState_Operating),
            f"the {Machine}'s copy of the player's state machine is in Operating (active states [{States}])");
        Assert_False(Get_IsStateActive(UMars_SmState_Locomotion), f"the {Machine}'s copy has left Locomotion (active states [{States}])");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(FRotator::ZeroRotator, _Base + k_StationFromBase), FMars_Station_Spec());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetStation_EntityScript, Params);
        Mark_Deadline(18.0);
        WaitUntil(n"Is_ServerOperating", n"OnServerChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOperating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsOperatingHere());
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Operating();
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientStationFound", n"OnClientStationFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientStationFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsStationFound());
    }

    UFUNCTION()
    private void OnClientStationFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Station))
        {
            Log_RealPawnRow(k_Row, "station=missing");
            FinishFailure("the client never saw the station the server spawned beside its pawn");
            return;
        }

        utils_station::Request_ActFor(_Station, _Player, EMars_Station_Verb::Reserve);
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientOperating", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientOperating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsOperatingHere());
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Operating();
        FinishSuccess();
    }
}
