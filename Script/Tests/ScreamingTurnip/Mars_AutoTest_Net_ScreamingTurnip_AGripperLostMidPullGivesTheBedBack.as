// A stand-in grips a replicated turnip bed and reports a pull of 0.6, then is destroyed: the client showed the stretch
// at the pull while it was held, and once the grip is released as GripperLost the client's holder is Nobody, its
// stretch unset, its target available and its bed still holds its charge.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_AGripperLostMidPullGivesTheBedBack
class UCk_AutoTest_Net_ScreamingTurnip_AGripperLostMidPullGivesTheBedBack : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(407000.0, 0.0, 5000.0);
    private const float32 k_ComposeSeconds = 2.0f;
    private const float32 k_ReportedPull = 0.6f;
    private const float32 k_HeldSeconds = 1.0f;

    private bool _SawHeld = false;
    private bool _ReachedPull = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BedFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientWatchedUntilReleased", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientWatchedUntilReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Control.Get_GripHolder() == EMars_Control_GripHolder::AnotherMachine)
        {
            _SawHeld = true;
            _ReachedPull = _ReachedPull || Math::Abs(Get_Stretch() - k_ReportedPull) <= k_StretchTolerance;
        }

        auto Result = OutResult;
        Result.Set(_SawHeld && _Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] AGripperLostMidPullGivesTheBedBack client: reachedPull {_ReachedPull}, {Get_BedText()}");
        Assert_True(_ReachedPull, "while the stand-in held, the client's stretch came within 0.05 of 0.6");
        Assert_True(_Control.Get_GripHolder() == EMars_Control_GripHolder::Nobody, f"the holder is Nobody (got {_Control.Get_GripHolder() :n})");
        Assert_False(_Control.TryGet_ShownGripAlpha().IsSet(), "the client's stretch is unset");
        Assert_True(Get_IsTargetEnabled(), "the client's target is available");
        Assert_True(_Forage.Get_ChargesLeft() == 1, f"the client's bed holds its one charge (got {_Forage.Get_ChargesLeft()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerBed();
        WaitUntil(n"Is_BedAndStandInFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(_StandIn, k_ReportedPull));
        WaitSeconds(k_HeldSeconds, n"OnServerHeldPull");
    }

    UFUNCTION()
    private void OnServerHeldPull(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_entity_lifetime::Request_DestroyEntity(_StandIn);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] AGripperLostMidPullGivesTheBedBack server: {Get_BedText()}");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::GripperLost,
            f"the grip was released GripperLost (got {_Control.Get_LastGripRelease() :n})");
        Assert_True(_Forage.Get_ReleasedCount() == 0, f"nothing was released (got {_Forage.Get_ReleasedCount()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
