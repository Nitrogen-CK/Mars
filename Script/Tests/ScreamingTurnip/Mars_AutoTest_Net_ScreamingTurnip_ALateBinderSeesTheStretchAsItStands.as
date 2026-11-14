// The server's stand-in grips a replicated turnip bed and reports a pull of 0.6 in the frame the server first finds it,
// before the client's copy composed. Once the client's ledger reads that grip, its copy shows the stretch at the pull
// and raised OnGripHolderChanged to AnotherMachine exactly once; after the stand-in lets go it raises the change to
// Nobody once and its stretch is unset.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_ALateBinderSeesTheStretchAsItStands
class UCk_AutoTest_Net_ScreamingTurnip_ALateBinderSeesTheStretchAsItStands : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(409000.0, 0.0, 5000.0);
    private const float32 k_ReportedPull = 0.6f;
    private const float32 k_HeldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientFoundGripped", n"OnClientFoundGripped", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientFoundGripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBedFound() && _Control.Get_IsGripped() && _Control.Get_GripPull() >= k_ReportedPull - 0.01f);
    }

    UFUNCTION()
    private void OnClientFoundGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_StretchAtThePull", n"OnClientStretched", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_StretchAtThePull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Math::Abs(Get_Stretch() - k_ReportedPull) <= k_StretchTolerance);
    }

    UFUNCTION()
    private void OnClientStretched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Count_HolderChangesTo(EMars_Control_GripHolder::AnotherMachine) == 1,
            f"the client raised OnGripHolderChanged to AnotherMachine exactly once (got [{Get_HolderChangesText()}])");
        WaitUntil(n"Is_GripReleased", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] ALateBinderSeesTheStretchAsItStands client: {Get_BedText()}");
        Assert_True(Count_HolderChangesTo(EMars_Control_GripHolder::AnotherMachine) == 1
            && Count_HolderChanges(EMars_Control_GripHolder::AnotherMachine, EMars_Control_GripHolder::Nobody) == 1 && _HolderChanges.Num() == 2,
            f"after the let-go the client raised the change to Nobody once (got [{Get_HolderChangesText()}])");
        Assert_False(_Control.TryGet_ShownGripAlpha().IsSet(), "the client's stretch is unset");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        WaitUntil(n"Is_StandInFound", n"OnServerStandInFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStandInFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBed();
        WaitUntil(n"Is_BedFound", n"OnServerBedFound", k_SlowPolls);
    }

    // The client's copy has not composed yet: what it finds is the grip as it stands.
    UFUNCTION()
    private void OnServerBedFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(_StandIn, k_ReportedPull));
        WaitSeconds(k_HeldSeconds, n"OnServerHeldPull");
    }

    UFUNCTION()
    private void OnServerHeldPull(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::LetGo);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] ALateBinderSeesTheStretchAsItStands server: {Get_BedText()}");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended,
            f"the stand-in's grip was released Ended (got {_Control.Get_LastGripRelease() :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
