// Two roots on one floor, one screaming every few seconds and one held in a long breath: each copy on the client
// follows its own root's ledger, every scream it records is the first root's, and the breathing root shows no Scream.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_TwoRootsKeepTheirOwnLedgers
class UCk_AutoTest_Net_ScreamingTurnip_TwoRootsKeepTheirOwnLedgers : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(605000.0, 0.0, 5000.0);
    private const int32 k_RootA = 0;
    private const int32 k_RootB = 1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);
        Expect_Root(FVector(0.0, -400.0, 0.0));
        Expect_Root(FVector(0.0, 400.0, 0.0));

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BothFound", n"OnClientBothFound", k_SlowPolls);
            return;
        }

        Spawn_ServerTurnipFloor();
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BothFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto FoundA = Get_IsRootFound(k_RootA);
        const auto FoundB = Get_IsRootFound(k_RootB);
        auto Result = OutResult;
        Result.Set(FoundA && FoundB);
    }

    UFUNCTION()
    private void Is_ASecondScream(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto FoundB = Get_IsRootFound(k_RootB);
        auto Result = OutResult;
        Result.Set(FoundB && Get_RootSequence(k_RootA) >= 2);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerRoot(k_RootA, Make_NetVocal());
        Spawn_ServerRoot(k_RootB, Make_LongInhaleVocal());
        WaitUntil(n"Is_ASecondScream", n"OnServerASecondScream", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerASecondScream(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] TwoRootsKeepTheirOwnLedgers server: A {Get_RootText(k_RootA)}; B {Get_RootText(k_RootB)}";
        Log(Line);
        Assert_Equals_Int(_Roots[k_RootA].Turnip.Get_ScreamSequence(), 2, "the server's root A reads sequence 2");
        Assert_Equals_Int(_Roots[k_RootB].Turnip.Get_ScreamSequence(), 0, "the server's root B reads sequence 0");
        Assert_True(_Roots[k_RootB].Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Inhale,
            f"the server's root B is in its long Inhale (got {_Roots[k_RootB].Turnip.Get_Phase() :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the server (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientBothFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ASecondScream", n"OnClientASecondScream", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientASecondScream(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRootGone(k_RootA) || Get_IsRootGone(k_RootB))
        { FinishFailure("a client's copy was gone before it was checked"); return; }

        const auto Line = f"[TurnipNetTest] TwoRootsKeepTheirOwnLedgers client: A {Get_RootText(k_RootA)}; B {Get_RootText(k_RootB)}";
        Log(Line);
        const auto LedgerA = TryGet_Ledger(k_RootA);
        const auto LedgerB = TryGet_Ledger(k_RootB);
        Assert_True(_Roots[k_RootA].Screams.Num() > 0 && _Roots[k_RootB].Screams.Num() == 0, "every scream the client recorded names root A");
        Assert_True(LedgerA.IsSet() && LedgerA.GetValue().ScreamSequence == 2, "the client's ledger of root A reads sequence 2");
        Assert_True(LedgerB.IsSet() && LedgerB.GetValue().Phase == EMars_ScreamingTurnip_Phase::Inhale && LedgerB.GetValue().ScreamSequence == 0,
            "the client's ledger of root B reads Inhale and sequence 0");
        Assert_Equals_Int(Count_PhaseEntries(k_RootB, EMars_ScreamingTurnip_Phase::Scream, 0), 0, "root B's phases on the client hold no Scream");
        const auto PositionA = _Roots[k_RootA].Turnip.Get_LastScreamPosition();
        const auto PositionB = _Roots[k_RootB].Turnip.Get_LastScreamPosition();
        Assert_True(PositionA.Equals(PositionB, 1.0) == false && PositionB.IsZero(), "the two last-scream positions differ, root B's is zero");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the client (got {Get_NewEnsures()})");
        FinishSuccess();
    }
}
