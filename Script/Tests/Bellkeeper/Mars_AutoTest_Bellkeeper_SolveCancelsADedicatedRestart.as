// Solve in the same drain as the stop acknowledgement: its queued Running must lose to Solve, even with stale events.
class UMars_AutoTest_Bellkeeper_SolveCancelsADedicatedRestart : UMars_AutoTestRig_BellkeeperDedicatedVent
{
    default _TimeoutSeconds = 12.0f;
    private bool _SolveAtStop = false;
    private bool _SawAwaitStopped = false;
    private FCk_Handle_Timer _OldTimer;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddDedicatedLock(InHandle);
        _Bellkeeper.BindTo_OnCommitFailed(FMars_Delegate_Bellkeeper_OnCommitFailed(this, n"OnWrongCommit"));
        _VentCycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnStop"));
        Add_Step("wrong commit", n"Step_FirstCommit");
        Add_Step_WaitUntil("actual Fire", n"Check_Fire", k_SlowPolls, 0);
        Add_Step("restart and solve at its stop acknowledgement", n"Step_Restart");
        Add_Step_WaitUntil("solved with actual trap stopped/disarmed", n"Check_Solved", k_SlowPolls, 0);
        Add_Step("replay stale acknowledgements/expiry", n"Step_StaleEvents");
        Add_Step_WaitSeconds("outlast old pulse", 2.2f);
        Add_Step("no restart or duplicate payout", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_FirstCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit()); }

    UFUNCTION()
    private void Check_Fire(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFiring());
    }

    UFUNCTION()
    private void Step_Restart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OldTimer = _Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper).VentTimer;
        _SolveAtStop = true;
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void OnWrongCommit(FCk_Handle_Bellkeeper InLock, int32 InRemaining)
    {
        if (_SolveAtStop && InLock.Get_FailedCommits() == 2)
        { Request_SetDials(Get_Answer()); }
    }

    UFUNCTION()
    private void OnStop(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InState)
    {
        if (_SolveAtStop && InState == EMars_Cycle_RunState::Stopped)
        {
            _SolveAtStop = false;
            _SawAwaitStopped = _Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper).VentTransition == EMars_Bellkeeper_VentTransition::AwaitStopped;
            _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
        }
    }

    UFUNCTION()
    private void Check_Solved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Bellkeeper.Get_IsSolved() && Get_IsDrained() && _VentCycle.Get_IsRunning() == false
            && _Hazard.Get_IsArmed() == false && _VentSource.Get_IsAsserted() == false && _OutputSource.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_StaleEvents(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Bellkeeper.Request_VentCycleChanged(FMars_Request_Bellkeeper_VentCycleChanged(_VentCycle, EMars_Cycle_RunState::Running));
        _Bellkeeper.Request_VentCycleChanged(FMars_Request_Bellkeeper_VentCycleChanged(_VentCycle, EMars_Cycle_RunState::Stopped));
        _Bellkeeper.Request_EndVent(FMars_Request_Bellkeeper_EndVent(_OldTimer));
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[BellkeeperSolveCancel] pendingObserved={_SawAwaitStopped} telegraphs={_TelegraphTimes.Num()} fires={_FireTimes.Num()} solved={_Bellkeeper.Get_IsSolved()}");
        Assert_True(_SawAwaitStopped, "answer committed with stop acknowledgement pending");
        Assert_Equals_Int(_TelegraphTimes.Num(), 1, "restart never entered another Telegraph");
        Assert_False(_Bellkeeper.Get_IsVenting(), "no pending restart or clock");
        Assert_False(_VentCycle.Get_IsRunning(), "actual Cycle stays stopped");
        Assert_False(_Hazard.Get_IsArmed(), "actual hazard stays disarmed");
        Assert_Equals_Int(_Bellkeeper.Get_RewardHandles().Num(), 1, "one remaining reward paid once");
    }
}
