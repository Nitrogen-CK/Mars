// A root warning on a long anticipation: the client's copy shows Anticipate, announced at most once, its age measured
// on the client's own clock from when the level reached it, and no scream. A lane cannot make the copy compose late, so
// the checks hold on both paths and the log line says which ran: no recorded entry (the ledger stood when the copy
// bound) or one (it arrived after).
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_ALateBinderSeesTheWarningFromItsStart
class UCk_AutoTest_Net_ScreamingTurnip_ALateBinderSeesTheWarningFromItsStart : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(604000.0, 0.0, 5000.0);
    private const float32 k_ServerAnticipateSeconds = 4.0f;
    private const float32 k_MinAgeSeconds = 0.8f;
    private const float32 k_MaxAgeSeconds = 3.0f;

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

    UFUNCTION()
    private void Is_Anticipate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootPhase(0, EMars_ScreamingTurnip_Phase::Anticipate));
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerRoot(0, Make_LongAnticipateVocal());
        WaitUntil(n"Is_Anticipate", n"OnServerAnticipate", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerAnticipate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerAnticipateSeconds, n"OnServerWarned");
    }

    UFUNCTION()
    private void OnServerWarned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] ALateBinderSeesTheWarningFromItsStart server: {Get_RootText(0)}";
        Log(Line);
        Assert_True(_Roots[0].Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Anticipate, f"the server's root still reads Anticipate (got {_Roots[0].Turnip.Get_Phase() :n})");
        Assert_Equals_Int(_Roots[0].Turnip.Get_ScreamSequence(), 0, "the server committed no scream");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the server (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Anticipate", n"OnClientAnticipate", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAnticipate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRootGone(0))
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Entries = Count_PhaseEntries(0, EMars_ScreamingTurnip_Phase::Anticipate, 0);
        const auto Path = Entries == 0 ? FString("the ledger stood when the copy bound") : FString("the ledger arrived after the copy bound");
        const auto Age = Get_PhaseAge(0);
        const auto Line = f"[TurnipNetTest] ALateBinderSeesTheWarningFromItsStart client: anticipateEntries {Entries} ({Path}), age {Age :.3}, {Get_RootText(0)}";
        Log(Line);
        auto Turnip = _Roots[0].Turnip;
        Assert_True(Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Anticipate, f"the client's copy still reads Anticipate (got {Turnip.Get_Phase() :n})");
        Assert_True(Entries <= 1, f"OnPhaseChanged into Anticipate was raised at most once on the client (got {Entries})");
        Assert_True(Age >= k_MinAgeSeconds && Age <= k_MaxAgeSeconds, f"the copy's phase age is measured from its arrival (got {Age})");
        Assert_Equals_Int(Turnip.Get_ScreamSequence(), 0, "the client's copy reads sequence 0");
        Assert_Equals_Int(_Roots[0].Screams.Num(), 0, "the client recorded no scream");
        Assert_False(Turnip.Get_LastScreamCommittedAt().IsSet(), "the client's copy has no last commit");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the client (got {Get_NewEnsures()})");
        FinishSuccess();
    }
}
