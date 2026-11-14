// A held root drawing a long breath is thrown: on both machines the Inhale it was thrown in is followed by Dormant, no
// scream is committed or raised, and on the client the copy no longer reads Held while its own world item is back in
// the World.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_AThrowCutsTheWarningOnBothMachines
class UCk_AutoTest_Net_ScreamingTurnip_AThrowCutsTheWarningOnBothMachines : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(602000.0, 0.0, 5000.0);
    private const float32 k_ServerInhaleSeconds = 1.5f;
    private const float32 k_ServerLooseSeconds = 3.0f;
    private const FVector k_ThrowVelocity = FVector(250.0, 0.0, 200.0);

    // The recorded entry into the Inhale the root was thrown in; -1 before it is known.
    private int32 _InhaleEntry = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);
        Expect_Root(FVector::ZeroVector);
        Compose_TurnipCarrier(k_Location + FVector(-200.0, 0.0, 100.0));

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_HeldInInhale", n"OnClientHeldInInhale", k_SlowPolls);
            return;
        }

        Spawn_ServerTurnipFloor();
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_HeldInInhale(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootIn(0, EMars_ScreamingTurnip_Placement::Held) && Get_IsRootPhase(0, EMars_ScreamingTurnip_Phase::Inhale));
    }

    UFUNCTION()
    private void Is_Loose(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootIn(0, EMars_ScreamingTurnip_Placement::Loose));
    }

    UFUNCTION()
    private void Is_Dormant(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootPhase(0, EMars_ScreamingTurnip_Phase::Dormant));
    }

    // The last recorded entry into Inhale.
    private int32 Find_LastInhaleEntry() const
    {
        auto Found = -1;
        for (int32 Entry = 0; Entry < _Roots[0].Phases.Num(); ++Entry)
        {
            if (_Roots[0].Phases[Entry].New == EMars_ScreamingTurnip_Phase::Inhale)
            { Found = Entry; }
        }

        return Found;
    }

    private bool Get_IsDormantAfterTheInhale() const
    {
        const auto& Phases = _Roots[0].Phases;
        return _InhaleEntry >= 0 && _InhaleEntry + 1 < Phases.Num() && Phases[_InhaleEntry + 1].New == EMars_ScreamingTurnip_Phase::Dormant;
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerRoot(0, Make_LongInhaleVocal());
        WaitUntil(n"Is_RootReadyToPickUp", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerPickUp(0);
        WaitUntil(n"Is_HeldInInhale", n"OnServerHeldInInhale", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHeldInInhale(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerInhaleSeconds, n"OnServerThrow");
    }

    UFUNCTION()
    private void OnServerThrow(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _InhaleEntry = Find_LastInhaleEntry();
        Request_ServerRelease(0, k_ThrowVelocity);
        WaitUntil(n"Is_Loose", n"OnServerLoose", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLoose(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerLooseSeconds, n"OnServerLanded");
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] AThrowCutsTheWarningOnBothMachines server: inhaleEntry {_InhaleEntry}, {Get_RootText(0)}";
        Log(Line);
        Assert_Equals_Int(_Roots[0].Turnip.Get_ScreamSequence(), 0, "the server committed no scream");
        Assert_Equals_Int(_Roots[0].Screams.Num(), 0, "the server raised no OnScreamCommitted");
        Assert_True(Get_IsDormantAfterTheInhale(), "the server's entry after the Inhale it threw in is Dormant");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the server (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientHeldInInhale(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _InhaleEntry = Find_LastInhaleEntry();
        WaitUntil(n"Is_Dormant", n"OnClientDormant", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientDormant(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRootGone(0))
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Line = f"[TurnipNetTest] AThrowCutsTheWarningOnBothMachines client: inhaleEntry {_InhaleEntry}, {Get_RootText(0)}";
        Log(Line);
        auto Turnip = _Roots[0].Turnip;
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), 0, "the client's copy reads sequence 0");
        Assert_Equals_Int(_Roots[0].Screams.Num(), 0, "the client recorded no scream");
        Assert_Equals_Int(Count_PhaseEntries(0, EMars_ScreamingTurnip_Phase::Scream, 0), 0, "no Scream among the client's phases");
        Assert_True(Get_IsDormantAfterTheInhale(), "the client's entry after that Inhale is Dormant");
        Assert_True(Turnip.Get_Placement() != EMars_ScreamingTurnip_Placement::Held, f"the client's copy no longer reads Held (got {Turnip.Get_Placement() :n})");
        Assert_True(Get_RootWorldItem(0).Get_Mount() == EMars_WorldItem_Mount::World, "the client's own world item is in the World");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the client (got {Get_NewEnsures()})");
        FinishSuccess();
    }
}
