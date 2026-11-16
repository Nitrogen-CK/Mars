// The server steps its dials onto the phrase and commits: its lock solves once, locks its dials and spawns the three
// rewards. The client's copy raises the solve once, its own dials stand on the phrase locked, and the rewards reach it
// as three world items beside the panel.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_TheRightCommitLocksTheDialsAndPaysOnBothMachines
class UCk_AutoTest_Net_Bellkeeper_TheRightCommitLocksTheDialsAndPaysOnBothMachines : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    private const float32 k_PaidHoldSeconds = 3.0f;
    private const float32 k_PaidLookSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(783000.0, 0.0, 5000.0));
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PanelFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // A copy the server already destroyed is not read.
    UFUNCTION()
    private void Is_LedgerOnThePhrase(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLockAlive() && Get_IndicesRead(Get_Ledger().DialIndices, FIntVector(1, 2, 3)));
    }

    // The server reads its lock, the client its ledger.
    UFUNCTION()
    private void Is_Solved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsLockAlive() == false)
        {
            Result.Set(false);
            return;
        }

        Result.Set(Get_IsServer() ? _Lock.Get_IsSolved() : Get_Ledger().Lock == EMars_Bellkeeper_Lock::Solved);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPanel(UMars_Bellkeeper_EntityScript);
        WaitUntil(n"Is_PanelFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSteps");
    }

    UFUNCTION()
    private void OnServerSteps(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Dials = _Lock.Get_Dials();
        for (int32 Index = 0; Index < Dials.Num(); ++Index)
        { Dials[Index].Request_Step(FMars_Request_Dial_Step(Index + 1)); }

        WaitUntil(n"Is_LedgerOnThePhrase", n"OnServerOnThePhrase", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOnThePhrase(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Lock.Request_Commit(FMars_Request_Bellkeeper_Commit());
        WaitUntil(n"Is_Solved", n"OnServerSolved", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_PaidHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto ValidRewards = 0;
        const auto RewardHandles = _Lock.Get_RewardHandles();
        for (const auto& Reward : RewardHandles)
        {
            if (ck::IsValid(Reward))
            { ValidRewards += 1; }
        }

        const auto Line = Log_BellLine(f"TheRightCommitLocksTheDialsAndPaysOnBothMachines validRewards={ValidRewards}");
        Assert_True(_Lock.Get_IsSolved(), f"the server's lock is solved ({Line})");
        Assert_Equals_Int(ValidRewards, 3, f"the server's lock holds three valid reward handles ({Line})");
        Assert_Equals_Int(Count_LockedDials(), 3, f"every server dial is locked ({Line})");
        Assert_Equals_Int(_SolvedFrames.Num(), 1, f"the server raised its solve once ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Solved", n"OnClientSolved", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_PaidLookSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Items = Count_WorldItemsNear();
        const auto Line = Log_BellLine(f"TheRightCommitLocksTheDialsAndPaysOnBothMachines itemsNear={Items}");
        Assert_Equals_Int(_SolvedFrames.Num(), 1, f"the client raised the solve once ({Line})");
        Assert_True(_Lock.Get_IsSolved(), f"the client's lock is solved ({Line})");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(1, 2, 3)), f"the client's own dials stand on the phrase ({Line})");
        Assert_Equals_Int(Count_LockedDials(), 3, f"every client dial is locked ({Line})");
        Assert_Equals_Int(Items, 3, f"three rewards reached the client as world items beside the panel ({Line})");
        Assert_Equals_Int(_FailedFrames.Num(), 0, f"the client raised no failure ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
