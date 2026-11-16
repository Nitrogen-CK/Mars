// A panel the server spawns reaches the client: its script, its root and its lock's ledger replicate; the copy composes
// the same plate and dials without authority, takes the ledger as it stands, counts the rewards from its spawn
// parameters and is offered no dial to grip. Whether each reward's definition reads on the client is logged.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_APanelComposesOnBothMachines
class UCk_AutoTest_Net_Bellkeeper_APanelComposesOnBothMachines : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    private const float32 k_ComposeLookSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(780000.0, 0.0, 5000.0));
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
        Spawn_ServerPanel(UMars_Bellkeeper_EntityScript);
        WaitUntil(n"Is_PanelFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeLookSeconds, n"OnServerLooked");
    }

    UFUNCTION()
    private void OnServerLooked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("APanelComposesOnBothMachines");
        const auto Ledger = Get_Ledger();
        Assert_True(utils_net::Get_HasAuthority(_Panel), f"the server has authority over its panel ({Line})");
        Assert_True(utils_entity_replication_driver::Has(_Panel), f"the server's panel has a replication driver ({Line})");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_Panel), f"the server's panel replicates ({Line})");
        Assert_True(Get_IsLockAlive(), f"the server's panel composed its lock ({Line})");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(0, 0, 0)), f"the server's three dials stand at 0, 0, 0 ({Line})");
        Assert_Equals_Int(Count_LockedDials(), 0, f"no server dial is locked ({Line})");
        Assert_True(_Lock.Has_Fragment(FMars_Fragment_Bellkeeper_Net), f"the server's lock carries its ledger ({Line})");
        Assert_True(Ledger.FailedCommits == 0 && Ledger.Lock == EMars_Bellkeeper_Lock::Sealed
            && Get_IndicesRead(Ledger.DialIndices, FIntVector(0, 0, 0)), f"the server's ledger reads 0, Sealed, [0, 0, 0] ({Line})");
        Assert_False(_Lock.Has_Fragment(FMars_Fragment_Bellkeeper_Mirror), f"the server's lock has no mirror ({Line})");
        Assert_True(ck::IsValid(_Panel.As_MechanismSink(ECk_SanityCheck::UnChecked)), f"the server's panel listens for commits ({Line})");
        Assert_Equals_Int(_Lock.Get_RemainingRewards(), 3, f"the server's lock has three rewards at stake ({Line})");
        Assert_Equals_Int(Count_DialsMayGripHere(), 3, f"every server dial may be gripped there ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ArriveSeconds, n"OnClientLooked");
    }

    UFUNCTION()
    private void OnClientLooked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto RewardsNull = "";
        if (Get_IsLockAlive())
        {
            const auto Rewards = _Lock.Get_Fragment(FMars_Fragment_Bellkeeper_Params).Rewards;
            for (const auto& Reward : Rewards)
            { RewardsNull += f"{Reward.Definition.IsNull()} "; }
        }

        const auto Row = f"APanelComposesOnBothMachines rewardDefinitionNull=[{RewardsNull}]";
        const auto Line = Log_BellLine(Row);
        Assert_True(Get_IsLockAlive(), f"the client's copy composed its lock ({Line})");
        Assert_False(utils_net::Get_HasAuthority(_Panel), f"the client has no authority over its copy ({Line})");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_Panel), f"the client's copy replicates ({Line})");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(0, 0, 0)), f"the client's own three dials stand at 0, 0, 0 ({Line})");
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 0, f"the client's lock counts no failure ({Line})");
        Assert_False(_Lock.Get_IsSolved(), f"the client's lock is not solved ({Line})");
        Assert_Equals_Int(_Lock.Get_RemainingRewards(), 3, f"the reward count crossed: three at stake on the client ({Line})");
        Assert_True(_Lock.Has_Fragment(FMars_Fragment_Bellkeeper_Mirror), f"the client's lock has its mirror ({Line})");
        Assert_True(Get_InitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_Equals_Int(Count_DialsMayGripHere(), 0, f"no client dial may be gripped there ({Line})");
        Assert_Equals_Int(_FailedFrames.Num(), 0, f"the client raised no failure ({Line})");
        Assert_Equals_Int(_SolvedFrames.Num(), 0, f"the client raised no solve ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
