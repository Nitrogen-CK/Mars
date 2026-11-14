// A Cancel the server applies lets the victim go on both machines: the server seizes A, cancels in Seize and seizes A
// again; the client's copy raises one Cancelled end with its copy of A, records Seize exactly twice and nothing else,
// marks A again, and its ledger reads Seize, serial 2, Cancelled.
// Surface: Ck.Devour.Net.AS_Devour_ACancelLetsTheVictimGoOnBothMachines
class UCk_AutoTest_Net_Devour_ACancelLetsTheVictimGoOnBothMachines : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_RowBase = FVector(623000.0, 0.0, 5000.0);
    private const FString k_Row = "ACancelLetsTheVictimGoOnBothMachines";

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

    UFUNCTION()
    private void Is_InSeize(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDevourerIn(EMars_Devour_Phase::Seize));
    }

    UFUNCTION()
    private void Is_SecondSeizeRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Count_DevourPhases(EMars_Devour_Phase::Seize) >= 2);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDevourRow(Make_LongSeizeTiming(), ECk_EnableDisable::Disable);
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
        WaitUntil(n"Is_InSeize", n"OnServerInSeize", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInSeize(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(1.5f, n"OnServerSeizeWaited");
    }

    UFUNCTION()
    private void OnServerSeizeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_DevourCancel();
        WaitUntil(n"Is_DevourEndedOnce", n"OnServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerEndWaited");
    }

    UFUNCTION()
    private void OnServerEndWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_DevourBegin(_VictimA);
        WaitUntil(n"Is_SecondSeizeRecorded", n"OnServerSecondSeize", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSecondSeize(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(2.0f, n"OnServerSecondSeizeWaited");
    }

    UFUNCTION()
    private void OnServerSecondSeizeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the server raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Cancelled, "the server's run ended Cancelled");
        Assert_Equals_Int(Get_DevourLedger().Serial, 2, "the server's ledger reads serial 2");
        Hold_DevourServerRow(k_Row, "");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_AMarked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMarkedByDevourer(_VictimA));
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_AMarked", n"OnClientAMarked", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAMarked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_DevourEndedOnce", n"OnClientEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_SecondSeizeRecorded", n"OnClientSecondSeize", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSecondSeize(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_DevourLedger();
        Log_DevourRow(k_Row, "");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded exactly once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Cancelled, "the client's run ended Cancelled");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _VictimA, "the client's run ended with its copy of A");
        Assert_Equals_Int(Count_DevourPhases(EMars_Devour_Phase::Seize), 2, "the client recorded Seize exactly twice");
        Assert_Equals_Int(_DevourPhases.Num(), 2, "the client recorded nothing but the two Seizes");
        Assert_True(Get_IsMarkedByDevourer(_VictimA), "the client's copy of A is marked again");
        Assert_True(Ledger.Phase == EMars_Devour_Phase::Seize, "the client's ledger reads Seize");
        Assert_Equals_Int(Ledger.Serial, 2, "the client's ledger reads serial 2");
        Assert_True(Ledger.LastEnd == EMars_Devour_End::Cancelled, "the client's ledger reads Cancelled");
        Finish_DevourRow();
    }
}
