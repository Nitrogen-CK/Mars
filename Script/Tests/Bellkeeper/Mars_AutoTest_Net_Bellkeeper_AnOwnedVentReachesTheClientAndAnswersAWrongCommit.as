// A harness fixture: the real panel with its own vent below it and no vent channel. Only its authority asks for the
// vent; a copy composes its lock in its construct and the vent arrives as its child.
class UMars_TESTONLY_NetBellkeeper_OwnedVent_EntityScript : UMars_Bellkeeper_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle))
        {
            OwnedVent.Enabled = true;
            OwnedVent.OffsetWorld = FVector(0.0, 0.0, -120.0);
            VentChannel = FGameplayTag();
        }

        return Super::DoConstruct(InHandle);
    }
}

// The server's panel owns its vent (the fixture above): the vent replicates as the panel's child and the client's copy
// finds it under its own panel. A wrong commit runs the vent's cycle on the server and its copy shows it running, then
// stopped; the client raises the failure once.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_AnOwnedVentReachesTheClientAndAnswersAWrongCommit
class UCk_AutoTest_Net_Bellkeeper_AnOwnedVentReachesTheClientAndAnswersAWrongCommit : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    private const float32 k_StopWaitSeconds = 10.0f;
    private const float32 k_SampleAfterFailureSeconds = 3.0f;
    // The client samples its vent for a while after the failure reaches it: the server's panel outlasts that window.
    private const float32 k_VentHoldSeconds = 4.5f;

    private FCk_Handle_Cycle _VentCycle;
    private FCk_Handle _VentCopy;
    private float64 _StopWaitStart = 0.0;
    private TOptional<float64> _FailureSeenAt;
    private int32 _RunningSamples = 0;
    private int32 _Samples = 0;
    private bool _LastSampleRunning = false;
    private int32 _VentFoundFrame = -1;
    private int32 _FirstRunningFrame = -1;
    private int32 _LastRunningFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(787000.0, 0.0, 5000.0));
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PanelFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private FString Describe_Vent()
    {
        return f"ventFound@{_VentFoundFrame} samples={_Samples} running={_RunningSamples} firstRunning@{_FirstRunningFrame} lastRunning@{_LastRunningFrame} lastSampleRunning={_LastSampleRunning}";
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPanel(UMars_TESTONLY_NetBellkeeper_OwnedVent_EntityScript);
        WaitUntil(n"Is_PanelFound", n"OnServerFound", k_SlowPolls);
    }

    // The lock composes once its vent has: the find is that frame.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Vent = Find_VentNear();
        _VentCycle = _Lock.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentCycle;
        const auto Line = Log_BellLine("AnOwnedVentReachesTheClientAndAnswersAWrongCommit lockComposed");
        Assert_True(ck::IsValid(Vent), f"one vent stands beside the server's panel ({Line})");
        Assert_True(ck::IsValid(Vent) && utils_entity_lifetime::Get_LifetimeOwner(Vent) == _Panel, f"the server's vent is its panel's child ({Line})");
        Assert_True(ck::IsValid(_VentCycle), f"the server's lock holds its vent's cycle ({Line})");
        WaitSeconds(k_SettleSeconds, n"OnServerCommit");
    }

    UFUNCTION()
    private void OnServerCommit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BellLine(f"AnOwnedVentReachesTheClientAndAnswersAWrongCommit commit cycleRunning={_VentCycle.Get_IsRunning()}");
        _Lock.Request_Commit(FMars_Request_Bellkeeper_Commit());
        WaitUntil(n"Is_ServerVentRunning", n"OnServerVentRunning", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerVentRunning(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_VentCycle) && _VentCycle.Get_IsRunning());
    }

    UFUNCTION()
    private void OnServerVentRunning(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BellLine("AnOwnedVentReachesTheClientAndAnswersAWrongCommit ventRunning");
        _StopWaitStart = System::GetGameTimeInSeconds();
        WaitUntil(n"Is_ServerVentStoppedOrLate", n"OnServerVentStopped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerVentStoppedOrLate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Late = System::GetGameTimeInSeconds() - _StopWaitStart > k_StopWaitSeconds;
        Result.Set(Late || ck::Is_NOT_Valid(_VentCycle) || _VentCycle.Get_IsRunning() == false);
    }

    UFUNCTION()
    private void OnServerVentStopped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("AnOwnedVentReachesTheClientAndAnswersAWrongCommit ventStopped");
        Assert_True(ck::IsValid(_VentCycle) && _VentCycle.Get_IsRunning() == false, f"the server's vent stopped within its wait ({Line})");
        WaitSeconds(k_VentHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("AnOwnedVentReachesTheClientAndAnswersAWrongCommit");
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 1, f"the server's lock counts one failure ({Line})");
        Assert_False(_Lock.Get_IsVenting(), f"the server's lock is no longer venting ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientVentArrived", n"OnClientVentArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientVentArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _VentCopy = Find_VentNear();
        Result.Set(ck::IsValid(_VentCopy));
    }

    UFUNCTION()
    private void OnClientVentArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _VentFoundFrame = Get_BellFrame();
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(_VentCopy);
        const auto Line = Log_BellLine(f"AnOwnedVentReachesTheClientAndAnswersAWrongCommit ventArrived ownerIsPanel={Owner == _Panel}");
        Assert_True(Owner == _Panel, f"the client's vent is its panel copy's child ({Line})");
        Assert_False(utils_net::Get_HasAuthority(_VentCopy), f"the client has no authority over its vent ({Line})");
        WaitUntil(n"Is_ClientSampledPastTheFailure", n"OnClientSampled", k_SlowPolls);
    }

    // Each poll samples the vent copy's cycle, until the ledger has read one failure for a few seconds.
    UFUNCTION()
    private void Is_ClientSampledPastTheFailure(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsLockAlive() == false || ck::Is_NOT_Valid(_VentCopy))
        {
            Result.Set(false);
            return;
        }

        const auto Cycle = _VentCopy.As_Cycle(ECk_SanityCheck::UnChecked);
        _LastSampleRunning = ck::IsValid(Cycle) && Cycle.Get_IsRunning();
        _Samples += 1;
        if (_LastSampleRunning)
        {
            _RunningSamples += 1;
            _LastRunningFrame = Get_BellFrame();
            if (_FirstRunningFrame < 0)
            { _FirstRunningFrame = _LastRunningFrame; }
        }

        const auto Now = System::GetGameTimeInSeconds();
        if (_FailureSeenAt.IsSet() == false && Get_Ledger().FailedCommits >= 1)
        { _FailureSeenAt = TOptional<float64>(Now); }

        Result.Set(_FailureSeenAt.IsSet() && Now - _FailureSeenAt.GetValue() >= k_SampleAfterFailureSeconds);
    }

    UFUNCTION()
    private void OnClientSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine(f"AnOwnedVentReachesTheClientAndAnswersAWrongCommit {Describe_Vent()}");
        Assert_True(_RunningSamples > 0, f"the client's vent was seen running ({Line})");
        Assert_False(_LastSampleRunning, f"the client's vent was stopped in the last sample ({Line})");
        Assert_Equals_Int(_FailedFrames.Num(), 1, f"the client raised the failure once ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
