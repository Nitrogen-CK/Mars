// A harness fixture: the real panel, whose authority, as it composes, steps dial 0 two detents and commits, so its lock
// is born with one failure and dial 0 on 2. A copy is born into a panel that already failed once.
class UMars_TESTONLY_NetBellkeeper_BornFailed_EntityScript : UMars_Bellkeeper_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        auto BornLock = InHandle.As_Bellkeeper(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(BornLock) && BornLock.Get_Dials().Num() >= 1,
            f"[BellNetTest] [{InHandle.ToString()}] the born panel composed no lock with a dial"))
        { return Flow; }

        auto Dials = BornLock.Get_Dials();
        Dials[0].Request_Step(FMars_Request_Dial_Step(2));
        BornLock.Request_Commit(FMars_Request_Bellkeeper_Commit());
        return Flow;
    }
}

// The server's panel is born with one failure and dial 0 on 2 (the fixture above): the client's copy takes it as it
// stands, placing dial 0 without a click and raising no failure. A later wrong commit reaches it as it arrives: one
// failure, one reward left.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_ACopyBornAfterAFailedCommitRaisesNoPastFailure
class UCk_AutoTest_Net_Bellkeeper_ACopyBornAfterAFailedCommitRaisesNoPastFailure : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    private const float32 k_BornLookSeconds = 3.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(785000.0, 0.0, 5000.0));
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PanelFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The server reads its lock, the client its ledger. A copy the server already destroyed is not read.
    UFUNCTION()
    private void Is_TwoFailures(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsLockAlive() == false)
        {
            Result.Set(false);
            return;
        }

        Result.Set(Get_IsServer() ? _Lock.Get_FailedCommits() >= 2 : Get_Ledger().FailedCommits >= 2);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPanel(UMars_TESTONLY_NetBellkeeper_BornFailed_EntityScript);
        WaitUntil(n"Is_PanelFound", n"OnServerFound", k_SlowPolls);
    }

    // The server finds its panel before the spawn frame's drains have run: it reads the born state a beat later.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BellLine("ACopyBornAfterAFailedCommitRaisesNoPastFailure atFind");
        WaitSeconds(k_BornLookSeconds, n"OnServerBornSettled");
    }

    UFUNCTION()
    private void OnServerBornSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("ACopyBornAfterAFailedCommitRaisesNoPastFailure born");
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 1, f"the server's panel was born with one failure ({Line})");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(2, 0, 0)), f"the server's panel was born with dial 0 on 2 ({Line})");
        _Lock.Request_Commit(FMars_Request_Bellkeeper_Commit());
        WaitUntil(n"Is_TwoFailures", n"OnServerFailedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFailedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("ACopyBornAfterAFailedCommitRaisesNoPastFailure");
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 2, f"the server's lock counts two failures ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_TwoFailures", n"OnClientFailedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFailedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ArriveSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("ACopyBornAfterAFailedCommitRaisesNoPastFailure");
        const auto First = _Notifies.Num() > 0 ? _Notifies[0] : FMars_Fragment_Bellkeeper_Net();
        const auto FirstFrame = _NotifyFrames.Num() > 0 ? _NotifyFrames[0] : -1;
        auto LaterFrame = -1;
        for (int32 Index = 0; Index < _Notifies.Num(); ++Index)
        {
            if (_Notifies[Index].FailedCommits == 2)
            {
                LaterFrame = _NotifyFrames[Index];
                break;
            }
        }

        const auto FirstCrossings = Get_FirstCrossingsOf(0);
        Assert_True(Get_InitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(First.FailedCommits == 1 && First.Lock == EMars_Bellkeeper_Lock::Sealed
            && Get_IndicesRead(First.DialIndices, FIntVector(2, 0, 0)), f"the first application carried the born state ({Line})");
        Assert_Equals_Int(FirstFrame, _FoundFrame, f"the first application arrived in the find frame ({Line})");
        Assert_True(_FailedRemaining.Num() == 1 && _FailedRemaining[0] == 1, f"the client raised one failure, one reward left ({Line})");
        Assert_True(LaterFrame >= 0 && _FailedFrames.Num() == 1 && _FailedFrames[0] == LaterFrame,
            f"the failure was raised at the later application ({Line})");
        Assert_True(_StateFrames.Contains(FirstFrame), f"the level change was raised at the first application ({Line})");
        const auto Indices = Get_DialIndices();
        Assert_True(Indices.Num() > 0 && Indices[0] == 2, f"the client's dial 0 reads 2 ({Line})");
        Assert_True(FirstCrossings.IsSet() && FirstCrossings.GetValue() == 0, f"dial 0 was placed without a click ({Line})");
        Assert_Equals_Int(_Lock.Get_RemainingRewards(), 1, f"one reward left on the client ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
