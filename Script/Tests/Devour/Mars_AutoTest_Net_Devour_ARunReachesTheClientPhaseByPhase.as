// A run the server decides reaches the client phase by phase: the server's devourer takes victim A through every phase
// and lets it go Completed; the client's copy, which has no authority, raises each phase once in run order and one
// Completed end with its copy of A, and stands Idle at the end with the ledger reading Idle, serial 1, Completed.
// Surface: Ck.Devour.Net.AS_Devour_ARunReachesTheClientPhaseByPhase
class UCk_AutoTest_Net_Devour_ARunReachesTheClientPhaseByPhase : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_RowBase = FVector(621000.0, 0.0, 5000.0);
    private const FString k_Row = "ARunReachesTheClientPhaseByPhase";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_DevourRow(k_RowBase, k_DevourerOffset, EMars_NetDevourTest_Victims::A);

        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerSpawnOwnerReady", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_DevourCopiesFound", n"OnClientFound", k_SlowPolls);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDevourRow(Make_NetTiming(), ECk_EnableDisable::Disable);
        WaitUntil(n"Is_DevourCopiesFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_DevourBegin(_VictimA);
        WaitUntil(n"Is_DevourEndedOnce", n"OnServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_DevourLedger();
        Assert_True(Get_AreDevourRuns(1), "the server recorded one run in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the server raised OnEnded once");
        Assert_True(_DevourEnds[0].End == EMars_Devour_End::Completed, "the run ended Completed");
        Assert_True(_DevourEnds[0].Victim == _VictimA, "the run ended with A");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the server's devourer is Idle");
        Assert_True(Ledger.Phase == EMars_Devour_Phase::Idle, "the server's ledger reads Idle");
        Assert_Equals_Int(Ledger.Serial, 1, "the server's ledger reads serial 1");
        Assert_True(Ledger.LastEnd == EMars_Devour_End::Completed, "the server's ledger reads Completed");
        Assert_True(Describe_RawVictim() == "self", "the server's ledger names the devourer itself while Idle");
        Hold_DevourServerRow(k_Row, "");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_DevourEndedOnce", n"OnClientEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_DevourLedger();
        const auto Alone = Count_DevourPhasesAlone();
        Log_DevourRow(k_Row, f"phasesAlone={Alone}");
        Assert_False(Get_HasDevourerAuthority(), "the client has no authority over the devourer");
        Assert_True(Get_AreDevourRuns(1), "the client recorded one run in run order, each phase once");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded once");
        Assert_True(_DevourEnds[0].End == EMars_Devour_End::Completed, "the client's run ended Completed");
        Assert_True(_DevourEnds[0].Victim == _VictimA, "the client's run ended with its copy of A");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the client's devourer is Idle");
        Assert_False(Get_HasRunningTag(), "the client's devourer has no Running tag");
        Assert_Equals_Float(_Devourer.Get_PhaseSeconds(), 0.0f, 0.0001f, "the client's PhaseSeconds is 0");
        Assert_True(Ledger.Phase == EMars_Devour_Phase::Idle, "the client's ledger reads Idle");
        Assert_Equals_Int(Ledger.Serial, 1, "the client's ledger reads serial 1");
        Assert_True(Ledger.LastEnd == EMars_Devour_End::Completed, "the client's ledger reads Completed");
        Finish_DevourRow();
    }
}
