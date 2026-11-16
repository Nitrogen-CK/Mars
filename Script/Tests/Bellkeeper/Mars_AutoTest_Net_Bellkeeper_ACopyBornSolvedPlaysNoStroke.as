// A harness fixture: the real panel, whose authority, as it composes, steps its dials onto the phrase and commits, so
// its lock is born solved with its dials locked and its rewards paid. A copy is born into a solved panel.
class UMars_TESTONLY_NetBellkeeper_BornSolved_EntityScript : UMars_Bellkeeper_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        auto BornLock = InHandle.As_Bellkeeper(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(BornLock) && BornLock.Get_Dials().Num() == 3,
            f"[BellNetTest] [{InHandle.ToString()}] the born panel composed no lock with three dials"))
        { return Flow; }

        auto Dials = BornLock.Get_Dials();
        for (int32 Index = 0; Index < Dials.Num(); ++Index)
        { Dials[Index].Request_Step(FMars_Request_Dial_Step(Index + 1)); }

        BornLock.Request_Commit(FMars_Request_Bellkeeper_Commit());
        return Flow;
    }
}

// The server's panel is born solved (the fixture above): the client's copy takes it as it stands, its own dials placed
// on the phrase and locked without a click, its level announced once and no solving stroke raised. The rewards the
// server paid reach it as world items.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_ACopyBornSolvedPlaysNoStroke
class UCk_AutoTest_Net_Bellkeeper_ACopyBornSolvedPlaysNoStroke : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    private const float32 k_BornHoldSeconds = 2.5f;
    private const float32 k_BornClientLookSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(786000.0, 0.0, 5000.0));
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PanelFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPanel(UMars_TESTONLY_NetBellkeeper_BornSolved_EntityScript);
        WaitUntil(n"Is_PanelFound", n"OnServerFound", k_SlowPolls);
    }

    // The server finds its panel before the spawn frame's drains have run: it reads the born state a beat later.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_BellLine("ACopyBornSolvedPlaysNoStroke atFind");
        WaitSeconds(k_SettleSeconds, n"OnServerBornSettled");
    }

    UFUNCTION()
    private void OnServerBornSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto ValidRewards = 0;
        const auto RewardHandles = _Lock.Get_RewardHandles();
        for (const auto& Reward : RewardHandles)
        {
            if (ck::IsValid(Reward))
            { ValidRewards += 1; }
        }

        const auto Line = Log_BellLine(f"ACopyBornSolvedPlaysNoStroke born validRewards={ValidRewards}");
        Assert_True(_Lock.Get_IsSolved(), f"the server's panel was born solved ({Line})");
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 0, f"the server's panel was born with no failure ({Line})");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(1, 2, 3)), f"the server's dials were born on the phrase ({Line})");
        Assert_Equals_Int(ValidRewards, 3, f"the server's panel was born with three rewards paid ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_BornHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BornClientLookSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Items = Count_WorldItemsNear();
        const auto Line = Log_BellLine(f"ACopyBornSolvedPlaysNoStroke itemsNear={Items}");
        const auto First = _Notifies.Num() > 0 ? _Notifies[0] : FMars_Fragment_Bellkeeper_Net();
        Assert_True(Get_InitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_Notifies.Num() > 0 && First.Lock == EMars_Bellkeeper_Lock::Solved
            && Get_IndicesRead(First.DialIndices, FIntVector(1, 2, 3)), f"the first application carried the solved lock and the phrase ({Line})");
        Assert_Equals_Int(_SolvedFrames.Num(), 0, f"the client raised no solve ({Line})");
        Assert_Equals_Int(_FailedFrames.Num(), 0, f"the client raised no failure ({Line})");
        Assert_Equals_Int(_StateFrames.Num(), 1, f"the client announced its level once ({Line})");
        Assert_True(_Lock.Get_IsSolved(), f"the client's lock is solved ({Line})");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(1, 2, 3)), f"the client's own dials stand on the phrase ({Line})");
        Assert_Equals_Int(Count_LockedDials(), 3, f"every client dial is locked ({Line})");
        Assert_Equals_Int(Get_CrossingsOf(-1), 0, f"no client dial clicked ({Line})");
        Assert_Equals_Int(Items, 3, f"three rewards reached the client as world items beside the panel ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
