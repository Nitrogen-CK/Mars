// A held root screams on both machines; once the selection is cleared it is stowed on the subject's Back, and from the
// moment each machine reads it Protected it stays Dormant, its sequence unchanged and no signal raised, while the
// client's own world item rides Carried on the subject.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_AStowedRootIsSilentOnBothMachines
class UCk_AutoTest_Net_ScreamingTurnip_AStowedRootIsSilentOnBothMachines : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(601000.0, 0.0, 5000.0);
    private const float32 k_ServerStowedSeconds = 7.0f;
    private const float32 k_ClientStowedSeconds = 5.0f;

    // What this machine read when it first read the root Protected.
    private int32 _SequenceAtStow = -1;
    private int32 _PhasesAtStow = 0;
    private int32 _ScreamsAtStow = 0;
    private int32 _SignalsAtStow = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);
        Expect_Root(FVector::ZeroVector);
        Compose_TurnipCarrier(k_Location + FVector(-200.0, 0.0, 100.0));

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ScreamedHeld", n"OnClientScreamedHeld", k_SlowPolls);
            return;
        }

        Spawn_ServerTurnipFloor();
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ScreamedHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootFound(0) && Get_IsRootGone(0) == false && Get_HasScreamWhile(0, EMars_ScreamingTurnip_Placement::Held));
    }

    UFUNCTION()
    private void Is_Protected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootIn(0, EMars_ScreamingTurnip_Placement::Protected));
    }

    private void Record_Stow()
    {
        _SequenceAtStow = Get_RootSequence(0);
        _PhasesAtStow = _Roots[0].Phases.Num();
        _ScreamsAtStow = _Roots[0].Screams.Num();
        _SignalsAtStow = Get_SignalCount(0);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerRoot(0, Make_NetVocal());
        WaitUntil(n"Is_RootReadyToPickUp", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerPickUp(0);
        WaitUntil(n"Is_ScreamedHeld", n"OnServerScreamedHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerScreamedHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerClearSelection();
        WaitUntil(n"Is_Protected", n"OnServerProtected", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerProtected(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Record_Stow();
        WaitSeconds(k_ServerStowedSeconds, n"OnServerStowed");
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] AStowedRootIsSilentOnBothMachines server: sequenceAtStow {_SequenceAtStow}, signalsAtStow {_SignalsAtStow}, {Get_RootText(0)}";
        Log(Line);
        auto Turnip = _Roots[0].Turnip;
        Assert_True(Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::Protected, f"the server's root reads Protected (got {Turnip.Get_Placement() :n})");
        Assert_True(Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Dormant, f"the server's root is Dormant (got {Turnip.Get_Phase() :n})");
        Assert_True(Get_RootWorldItem(0).Get_Mount() == EMars_WorldItem_Mount::Carried, "the server's root is Carried");
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), _SequenceAtStow, "the server's sequence is what it was at the stow");
        Assert_Equals_Int(Get_SignalCount(0), _SignalsAtStow, "the server's root raised no signal since it read Protected");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the server (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientScreamedHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Protected", n"OnClientProtected", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientProtected(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Record_Stow();
        WaitSeconds(k_ClientStowedSeconds, n"OnClientStowed");
    }

    UFUNCTION()
    private void OnClientStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRootGone(0))
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Line = f"[TurnipNetTest] AStowedRootIsSilentOnBothMachines client: sequenceAtStow {_SequenceAtStow}, signalsAtStow {_SignalsAtStow}, {Get_RootText(0)}";
        Log(Line);
        auto Turnip = _Roots[0].Turnip;
        auto WorldItem = Get_RootWorldItem(0);
        Assert_True(Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::Protected, f"the client's copy reads Protected (got {Turnip.Get_Placement() :n})");
        Assert_True(Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Dormant, f"the client's copy is Dormant (got {Turnip.Get_Phase() :n})");
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), _SequenceAtStow, "the client's sequence is unchanged since it read Protected");
        Assert_Equals_Int(_Roots[0].Phases.Num(), _PhasesAtStow, "the client's copy raised no OnPhaseChanged since it read Protected");
        Assert_Equals_Int(_Roots[0].Screams.Num(), _ScreamsAtStow, "the client's copy raised no OnScreamCommitted since it read Protected");
        Assert_True(WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried && WorldItem.Get_Carrier() == Get_SubjectEntity(),
            f"the client's own world item is Carried on the subject (got {WorldItem.Get_Mount() :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the client (got {Get_NewEnsures()})");
        FinishSuccess();
    }
}
