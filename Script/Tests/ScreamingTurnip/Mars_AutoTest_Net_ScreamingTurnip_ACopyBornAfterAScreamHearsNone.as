// A root that screamed before its copy existed: the server holds its ledger settled on the floor, recovering, with one
// scream committed at the root's spawn place, from the spawn frame on. The client's copy takes that state as it stands
// at its ledger's first application: placement and phase written and announced once each, the phase timed from then on
// the client's own clock, and no scream raised or latched (it was committed before the copy took its state).
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_ACopyBornAfterAScreamHearsNone
class UCk_AutoTest_Net_ScreamingTurnip_ACopyBornAfterAScreamHearsNone : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(607000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const float32 k_MinAgeSeconds = 0.8f;
    private const float32 k_MaxAgeSeconds = 3.0f;
    private const float64 k_PositionTolerance = 0.1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);
        Expect_Root(FVector::ZeroVector);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RootFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Spawn_ServerTurnipFloor();
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // Both machines compute it alike: settled on the floor, recovering, one scream at the root's spawn place.
    private FMars_Fragment_ScreamingTurnip_Net Make_HeldTurnipLedger() const
    {
        auto Ledger = FMars_Fragment_ScreamingTurnip_Net();
        Ledger.Placement = EMars_ScreamingTurnip_Placement::LooseSettled;
        Ledger.Phase = EMars_ScreamingTurnip_Phase::RecoveryIdle;
        Ledger.Support = EMars_ScreamingTurnip_Support::Supported;
        Ledger.ScreamSequence = 1;
        Ledger.ScreamPosition = _Roots[0].SpawnPlace + FVector(0.0, 0.0, 20.0);
        return Ledger;
    }

    private bool Get_IsHeldTurnipLedger(const FMars_Fragment_ScreamingTurnip_Net& InLedger) const
    {
        const auto Held = Make_HeldTurnipLedger();
        return InLedger.Placement == Held.Placement && InLedger.Phase == Held.Phase && InLedger.Support == Held.Support
            && InLedger.ScreamSequence == Held.ScreamSequence && InLedger.ScreamPosition.Equals(Held.ScreamPosition, k_PositionTolerance);
    }

    private bool Get_DoesLedgerReadHeld()
    {
        if (Get_IsRootFound(0) == false || Get_IsRootGone(0))
        { return false; }

        const auto Ledger = TryGet_Ledger(0);
        return Ledger.IsSet() && Get_IsHeldTurnipLedger(Ledger.GetValue());
    }

    // The held fixture's frames on this machine's root; "none" without it.
    private FString Describe_TurnipHeld()
    {
        if (Get_IsRootGone(0) || _Roots[0].Turnip.Has_Fragment(FMars_TESTONLY_Fragment_ScreamingTurnip_HeldLedger) == false)
        { return FString("none"); }

        const auto Held = _Roots[0].Turnip.Get_Fragment(FMars_TESTONLY_Fragment_ScreamingTurnip_HeldLedger);
        return f"{Held.ConstructFrame} {Held.FirstHoldFrame}";
    }

    UFUNCTION()
    private void Is_LedgerHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_DoesLedgerReadHeld());
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerHeldRoot(0, Make_NetVocal(), Make_HeldTurnipLedger());
        WaitUntil(n"Is_LedgerHeld", n"OnServerLedgerHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLedgerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] ACopyBornAfterAScreamHearsNone server: held=[{Describe_TurnipHeld()}], {Get_RootText(0)}";
        Log(Line);
        Assert_True(Get_DoesLedgerReadHeld(), "the server's ledger still reads the held state");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the server (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void Is_CopyOnSequenceOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Ledger = TryGet_Ledger(0);
        Result.Set(Ledger.IsSet() && Ledger.GetValue().ScreamSequence == 1);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CopyOnSequenceOne", n"OnClientSequenceOne", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSequenceOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRootGone(0))
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto& Root = _Roots[0];
        auto Turnip = Root.Turnip;
        const auto First = TryGet_RootFirstNotifyLedger(0);
        const auto FirstFrame = int64(Get_RootFirstNotifyFrame(0));
        const auto Now = TryGet_Ledger(0);
        const auto Path = Root.Screams.Num() == 0 ? FString("stood") : FString("arrived");
        const auto Age = Get_PhaseAge(0);
        const auto Line = f"[TurnipNetTest] ACopyBornAfterAScreamHearsNone client: path={Path} age={Age :.3}, {Get_RootText(0)}";
        Log(Line);

        Assert_True(Get_RootInitialState(0) == EMars_Net_InitialState::Taken, "the client's copy has taken the state it was born into");
        Assert_True(Root.InitialAtFind == EMars_Net_InitialState::Awaited, "the client found its copy before it took that state");
        Assert_True(First.IsSet(), "the client recorded its ledger's first rep-notify");
        Assert_True(Now.IsSet(), "the client's copy has its ledger");
        if (First.IsSet() == false || Now.IsSet() == false)
        { FinishFailure("the client's first notify or ledger is missing"); return; }

        auto EveryNotifyHeld = true;
        for (const auto& Ledger : Root.NotifyLedgers)
        {
            if (Get_IsHeldTurnipLedger(Ledger) == false)
            { EveryNotifyHeld = false; }
        }

        Assert_True(Get_IsHeldTurnipLedger(First.GetValue()), "the copy's first notify carried the held ledger");
        Assert_True(EveryNotifyHeld, "every notify the client recorded carried the held ledger");
        Assert_Equals_Int(Root.Screams.Num(), Now.GetValue().ScreamSequence - First.GetValue().ScreamSequence,
            "the screams the client recorded are those its ledger counted after its first notify");
        Assert_Equals_Int(Root.Screams.Num(), 0, "the client recorded no scream");
        Assert_False(Turnip.Get_LastScreamCommittedAt().IsSet(), "the client's copy latched no scream");
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), 1, "the client's copy reads sequence 1");
        Assert_True(Turnip.Get_LastScreamPosition().Equals(Make_HeldTurnipLedger().ScreamPosition, k_PositionTolerance),
            f"the client's copy reads the held scream position (got {Turnip.Get_LastScreamPosition().ToString()})");
        Assert_True(Turnip.Get_HasSupport(), "the client's copy reads supported");

        Assert_Equals_Int(Root.Placements.Num(), 1, "OnPlacementChanged was raised exactly once on the client");
        if (Root.Placements.Num() == 1)
        {
            Assert_True(Root.Placements[0].Previous == EMars_ScreamingTurnip_Placement::Loose
                && Root.Placements[0].New == EMars_ScreamingTurnip_Placement::LooseSettled, "the placement went Loose to LooseSettled");
            Assert_True(Root.Placements[0].Frame == FirstFrame, "the placement was announced in the first notify's frame");
        }

        Assert_Equals_Int(Root.Phases.Num(), 1, "OnPhaseChanged was raised exactly once on the client");
        if (Root.Phases.Num() == 1)
        {
            Assert_True(Root.Phases[0].Previous == EMars_ScreamingTurnip_Phase::Dormant
                && Root.Phases[0].New == EMars_ScreamingTurnip_Phase::RecoveryIdle, "the phase went Dormant to RecoveryIdle");
            Assert_True(Root.Phases[0].Frame == FirstFrame, "the phase was announced in the first notify's frame");
        }

        Assert_True(Age >= k_MinAgeSeconds && Age <= k_MaxAgeSeconds, f"the copy's phase age is measured from its first notify (got {Age})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the client (got {Get_NewEnsures()})");
        FinishSuccess();
    }
}
