// The server spawns two test operators and, once they have reached the client, a station whose authority asks to
// reserve it for each as it composes: its arbiter seats the first and refuses the second Occupied in the spawn frame.
// The client's copy is born into that state: it raises the holder once and not the refusal it was born into. The
// server then has the subject refused and releases the holder; the client raises each of those once, and the station
// ends free on both.
// Surface: Ck.Station.Net.AS_Station_ACopyBornHeldAndRefusedRaisesOnlyTheHolder
class UCk_AutoTest_Net_Station_ACopyBornHeldAndRefusedRaisesOnlyTheHolder : UMars_AutoTestRig_NetStation
{
    private const FVector k_Base = FVector(87000.0, 0.0, 5000.0);

    // Server: who the born station seated.
    private FCk_Handle _Holder;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientTwoRefusals", n"OnClientTwoRefusals", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerOperator();
        Spawn_ServerOperator();
        WaitUntil(n"Is_TwoOperatorsFound", n"OnServerOperatorsFound", k_SlowPolls);
    }

    // A settle, so both operators reach the client before the station does and its holder resolves there.
    UFUNCTION()
    private void OnServerOperatorsFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerOperatorsSettled");
    }

    UFUNCTION()
    private void OnServerOperatorsSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStationOfClass(k_Base, UMars_TESTONLY_NetStation_BornHeldAndRefused_EntityScript);
        WaitUntil(n"Is_StationFoundAndWatched", n"OnServerFound", k_SlowPolls);
    }

    // The server can find its station before the spawn frame's drain has run.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerBornHeldAndRefused", n"OnServerBorn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerBornHeldAndRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Station.Get_IsOperated() && _Station.Get_RefusalSerial() == 1);
    }

    UFUNCTION()
    private void OnServerBorn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Holder = _Station.Get_Operator();
        const auto Line = f"[StationNetTest] ACopyBornHeldAndRefusedRaisesOnlyTheHolder server born: {Describe_StationFind()} "
            + f"atFind={_StationLedgerAtFind.Occupancy :n}/{_StationLedgerAtFind.ReleaseSerial}/{_StationLedgerAtFind.RefusalSerial} "
            + f"now@{utils_time::Get_FrameCounter()}={Describe_Ledger()}";
        Log(Line);
        WaitSeconds(k_SettleSeconds, n"OnServerReserveForSubject");
    }

    UFUNCTION()
    private void OnServerReserveForSubject(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        WaitUntil(n"Is_TwoRefusals", n"OnServerTwoRefusals", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerTwoRefusals(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerRelease");
    }

    UFUNCTION()
    private void OnServerRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Station.Request_Release(FMars_Request_Station_Release(_Holder, EMars_Station_ReleaseReason::StationRequested));
        WaitUntil(n"Is_ServerFree", n"OnServerFree", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Station.Get_IsOperated() == false);
    }

    UFUNCTION()
    private void OnServerFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Refusals = _Station.Get_RefusalSerial();
        const auto Line = f"[StationNetTest] ACopyBornHeldAndRefusedRaisesOnlyTheHolder server: {Describe_StationFind()} "
            + f"atFind={_StationLedgerAtFind.RefusalSerial} ledger={Describe_Ledger()} ensures {Get_NewEnsures()}";
        Log(Line);

        Assert_Equals_Int(Refusals, 2, "the server's ledger counts two refusals");
        Assert_Equals_Int(_Station.Get_ReleaseSerial(), 1, "the server's ledger counts one release");
        Assert_True(_Station.Get_LastRefused() == Get_SubjectEntity(), "the server's last refusal names the subject");
        Assert_True(Get_IsFreeOf(Get_SubjectOperator()), "the server's station is free");
        Assert_Equals_Int(_Rejected.Num(), Refusals - _StationLedgerAtFind.RefusalSerial,
            f"the server raised every refusal after its find ({Describe_StationFind()})");
        Assert_True(Get_NewEnsures() == 0, f"the server fired no ensure (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    // Quiet once the copy is gone: the server may already have destroyed it.
    UFUNCTION()
    private void Is_ClientTwoRefusals(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFoundAndWatched() && _Station.Get_RefusalSerial() >= 2);
    }

    // The standing holder's announce reached the station's setup: the Use interactable holds the Operated claim.
    UFUNCTION()
    private void OnClientTwoRefusals(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_UseIsClaimed(), f"the client's Use interactable holds the Operated claim ({Describe_StationFind()})");
        WaitUntil(n"Is_ClientReleased", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStationFound() && _Station.Get_ReleaseSerial() >= 1);
    }

    // A settle, so a duplicate would have arrived.
    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto First = Get_FirstStationNotifyLedger();
        const auto FirstFrame = Get_FirstStationNotifyFrame();
        const auto FirstHolder = utils_station::Get_HeldBy(First);
        const auto Refusals = _Station.Get_RefusalSerial();
        const auto Releases = _Station.Get_ReleaseSerial();
        const auto Line = f"[StationNetTest] ACopyBornHeldAndRefusedRaisesOnlyTheHolder client: {Describe_StationFind()} "
            + f"ledger={Describe_Ledger()} claimed={Get_UseIsClaimed()} ensures {Get_NewEnsures()}";
        Log(Line);

        Assert_True(Get_StationInitialState() == EMars_Net_InitialState::Taken, "the client's copy took the state it was born into");
        Assert_True(_StationInitialAtFind == EMars_Net_InitialState::Awaited, "the client found its copy before its ledger's first application");
        Assert_True(_StationNotifyFrames.Num() > 0, "the client recorded a rep-notify of its station's ledger");
        Assert_True(First.Occupancy == EMars_Station_Occupancy::Operated && First.RefusalSerial == 1 && First.ReleaseSerial == 0,
            f"the first notify carried the held station with one refusal it was born into ({Describe_StationFind()})");
        Assert_True(ck::IsValid(FirstHolder), f"the first notify's holder resolves on the client ({Describe_StationFind()})");

        Assert_Equals_Int(_Reserved.Num(), 1, f"the client raised OnReserved once ({Describe_StationFind()})");
        Assert_True(_Reserved.Num() == 1 && _Reserved[0] == FirstHolder && _ReservedFrames[0] == FirstFrame,
            f"the client's OnReserved names the first notify's holder, in its frame ({Describe_StationFind()})");

        Assert_Equals_Int(_Rejected.Num(), Refusals - First.RefusalSerial,
            f"the client raised only the refusals after its first notify ({Describe_StationFind()})");
        Assert_True(_Rejected.Num() > 0 && _Rejected[0] == Get_SubjectEntity()
            && _RejectReasons[0] == EMars_Station_RejectReason::Occupied && _RejectedFrames[0] > FirstFrame,
            f"the client's first refusal names the subject, Occupied, after its first notify ({Describe_StationFind()})");

        Assert_Equals_Int(_Released.Num(), Releases - First.ReleaseSerial,
            f"the client raised only the releases after its first notify ({Describe_StationFind()})");
        Assert_True(_Released.Num() > 0 && _Released[0] == FirstHolder
            && _ReleaseReasons[0] == EMars_Station_ReleaseReason::StationRequested,
            f"the client's release names the first notify's holder, StationRequested ({Describe_StationFind()})");

        Assert_True(_Station.Get_IsOperated() == false && Get_UseIsClaimed() == false,
            f"the client's station is free and its Use claim gone ({Describe_StationFind()})");
        Assert_True(Get_NewEnsures() == 0, f"the client fired no ensure (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_TwoRefusals(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Station.Get_RefusalSerial() >= 2);
    }

    private FString Describe_Ledger()
    {
        const auto Occupancy = _Station.Get_IsOperated() ? "Operated" : "Free";
        return f"{Occupancy}/{_Station.Get_ReleaseSerial()}/{_Station.Get_RefusalSerial()} lastRefusal={_Station.Get_LastRefusal() :n}";
    }
}
