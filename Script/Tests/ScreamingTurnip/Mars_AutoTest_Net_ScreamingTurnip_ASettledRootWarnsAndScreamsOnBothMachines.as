// A root resting on the server's floor warns and screams on the authority's clock, and the client's copy shows the same
// cycle from the ledger: no authority and no body there, settled and supported, its phases in cycle order through a
// second scream, each scream once, the last one placed where the authority committed it.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_ASettledRootWarnsAndScreamsOnBothMachines
class UCk_AutoTest_Net_ScreamingTurnip_ASettledRootWarnsAndScreamsOnBothMachines : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(600000.0, 0.0, 5000.0);
    private const float64 k_PositionToleranceCm = 100.0;

    // The server's sampled ledger changes when its sequence first read 1 and 2.
    private int32 _ChangesAtFirst = -1;
    private int32 _ChangesAtSecond = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);
        Expect_Root(FVector::ZeroVector);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_SecondScream", n"OnClientSecondScream", k_SlowPolls);
            return;
        }

        Spawn_ServerTurnipFloor();
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_SecondScream(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsRootFound(0) == false || Get_IsRootGone(0))
        {
            Result.Set(false);
            return;
        }

        Sample_Ledger(0);
        const auto Sequence = Get_RootSequence(0);
        if (Sequence >= 1 && _ChangesAtFirst < 0)
        { _ChangesAtFirst = _Roots[0].LedgerChanges; }

        if (Sequence >= 2 && _ChangesAtSecond < 0)
        { _ChangesAtSecond = _Roots[0].LedgerChanges; }

        Result.Set(Sequence >= 2);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerRoot(0, Make_NetVocal());
        WaitUntil(n"Is_SecondScream", n"OnServerSecondScream", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSecondScream(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] ASettledRootWarnsAndScreamsOnBothMachines server: ledgerChangesOneCycle {_ChangesAtSecond - _ChangesAtFirst}, {Get_RootText(0)}";
        Log(Line);
        auto Turnip = _Roots[0].Turnip;
        const auto& Screams = _Roots[0].Screams;
        Assert_True(Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::LooseSettled,
            f"the server's root rests LooseSettled (got {Turnip.Get_Placement() :n})");
        Assert_True(Get_IsInCycleOrderFrom(0, EMars_ScreamingTurnip_Phase::Anticipate), "from its first Anticipate the server's phases are in cycle order");
        Assert_True(Screams.Num() == 2 && Screams[0].Sequence == 1 && Screams[1].Sequence == 2,
            f"the server raised OnScreamCommitted for 1 and 2, once each (got {Screams.Num()})");
        Assert_True(Get_IsLedgerTheState(0), "the server's ledger equals its state");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the server (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientSecondScream(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRootGone(0))
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Line = f"[TurnipNetTest] ASettledRootWarnsAndScreamsOnBothMachines client: {Get_RootText(0)}";
        Log(Line);
        auto Turnip = _Roots[0].Turnip;
        auto WorldItem = Get_RootWorldItem(0);
        const auto& Screams = _Roots[0].Screams;
        Assert_False(utils_net::Get_HasAuthority(Turnip), "the client has no authority over the root");
        Assert_False(ck::IsValid(WorldItem.Get_Body()), "the client's world item has no body");
        Assert_True(Turnip.Get_Placement() == EMars_ScreamingTurnip_Placement::LooseSettled,
            f"the client's copy reads LooseSettled (got {Turnip.Get_Placement() :n})");
        Assert_True(Turnip.Get_HasSupport(), "the client's copy reads supported");

        const auto FirstScream = Find_PhaseEntry(0, EMars_ScreamingTurnip_Phase::Scream, 0);
        Assert_True(Get_IsInCycleOrderFrom(0, EMars_ScreamingTurnip_Phase::Scream), "from its first Scream the client's phases are in cycle order");
        Assert_True(Find_PhaseEntry(0, EMars_ScreamingTurnip_Phase::Scream, FirstScream + 1) > FirstScream && FirstScream >= 0,
            "the client's phases reach a second Scream");

        auto Ordered = Screams.Num() > 0;
        for (int32 Index = 1; Index < Screams.Num(); ++Index)
        { Ordered = Ordered && Screams[Index].Sequence == Screams[Index - 1].Sequence + 1; }

        Assert_True(Ordered && Screams.Last().Sequence == 2, f"each scream the client recorded is one more than the one before and the last is 2 (got {Screams.Num()})");
        Assert_Equals_Int(Count_PhaseEntries(0, EMars_ScreamingTurnip_Phase::Scream, 0), Screams.Num(), "as many entries into Scream as screams the client recorded");

        if (Screams.Num() > 0)
        {
            const auto Last = Screams.Last().Position;
            const auto Ledger = TryGet_Ledger(0);
            const auto RootLocation = Get_TurnipRootLocation(0);
            Assert_True(Last.Equals(Turnip.Get_LastScreamPosition(), 0.0), "the last scream's position is the copy's Get_LastScreamPosition");
            Assert_True(Ledger.IsSet() && Last.Equals(Ledger.GetValue().ScreamPosition, 0.0), "the last scream's position is the ledger's");
            Assert_True((Last - RootLocation).Size() <= k_PositionToleranceCm,
                f"the last scream lies near the client's root (off by {(Last - RootLocation).Size()} cm)");
        }

        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the client (got {Get_NewEnsures()})");
        FinishSuccess();
    }
}
