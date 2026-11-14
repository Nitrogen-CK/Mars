// A copy that composes into a run sees it to its end: the server makes A prey and raises the channel before the steward
// exists, so the steward's first evaluation finds the channel risen and seizes A at once; the client's copy, composed
// before the run or while it stands or arrives, records at most six phases, consecutive and ending at Swallowed, ends
// once Completed and stands Idle with no Running tag, A unmarked and its ledger reading Idle, serial 1, Completed. Its
// line says how many phases it recorded and the first: six from Seize means it composed before the run.
// Surface: Ck.Steward.Net.AS_Steward_ACopyThatComposesIntoARunSeesItToItsEnd
class UCk_AutoTest_Net_Steward_ACopyThatComposesIntoARunSeesItToItsEnd : UMars_AutoTestRig_NetSteward
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_RowBase = FVector(646000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyThatComposesIntoARunSeesItToItsEnd";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_StewardRow(k_RowBase, EMars_NetDevourTest_Victims::A);

        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerSpawnOwnerReady", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_StewardCopiesFound", n"OnClientFound", k_SlowPolls);
    }

    private FString Describe_Recorded()
    {
        const auto First = _DevourPhases.Num() > 0 ? f"{_DevourPhases[0].Phase :n}" : FString("none");
        return f"recorded={_DevourPhases.Num()} first={First}";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStewardVictims();
        WaitUntil(n"Is_StewardVictimAFound", n"OnServerFoundA", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFoundA(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_MakePrey(_VictimA);
        Spawn_ServerFailSource(EMars_MechanismSource_Output::Asserted);
        Spawn_ServerSteward();
        WaitUntil(n"Is_StewardEndedOnce", n"OnServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_AreDevourPhasesConsecutive(), "the server's recorded phases are consecutive");
        Assert_True(Get_DoPhasesEndAtSwallowed(), "the server's recorded phases end at Swallowed");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the server raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _VictimA, "the run ended with A");
        Assert_Equals_Int(Get_DevourLedger().Serial, 1, "the server's ledger reads serial 1");
        Hold_StewardServerRow(k_Row, Describe_Recorded());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_StewardEndedOnce", n"OnClientEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_DevourLedger();
        Log_StewardRow(k_Row, Describe_Recorded());
        Assert_True(_DevourPhases.Num() <= 6, "the client recorded at most six phases");
        Assert_True(Get_AreDevourPhasesConsecutive(), "the client's recorded phases are consecutive");
        Assert_True(Get_DoPhasesEndAtSwallowed(), "the client's recorded phases end at Swallowed");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded exactly once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the client's run ended Completed");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the client's steward is Idle");
        Assert_False(Get_HasRunningTag(), "the client's steward has no Running tag");
        Assert_False(Get_HasVictimMarker(_VictimA), "the client's copy of A has no marker");
        Assert_True(Ledger.Phase == EMars_Devour_Phase::Idle, "the client's ledger reads Idle");
        Assert_Equals_Int(Ledger.Serial, 1, "the client's ledger reads serial 1");
        Assert_True(Ledger.LastEnd == EMars_Devour_End::Completed, "the client's ledger reads Completed");
        Finish_DevourRow();
    }
}
