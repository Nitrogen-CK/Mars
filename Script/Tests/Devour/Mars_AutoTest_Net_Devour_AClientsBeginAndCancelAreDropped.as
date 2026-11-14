// A client's Begin and Cancel on its copy of a devourer are dropped: the client asks its copy to seize A and nothing
// happens on either machine (Idle, serial 0, nobody marked, no signal, the requests gone); once the server's devourer
// holds B, the client's Cancel leaves it in Seize with B marked and no end.
// Surface: Ck.Devour.Net.AS_Devour_AClientsBeginAndCancelAreDropped
class UCk_AutoTest_Net_Devour_AClientsBeginAndCancelAreDropped : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_RowBase = FVector(626000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsBeginAndCancelAreDropped";
    private const float32 k_DroppedSeconds = 1.5f;
    private const float32 k_WatchSeconds = 3.0f;

    private FString _AfterBegin = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_DevourRow(k_RowBase, k_DevourerOffset, EMars_NetDevourTest_Victims::AAndB);

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
        WaitSeconds(k_ComposeSeconds + k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AfterBegin = f"watched=[phase {_Devourer.Get_Phase() :n} serial {Get_DevourLedger().Serial} marked {Describe_Marked()}]";
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the server's devourer stayed Idle");
        Assert_Equals_Int(Get_DevourLedger().Serial, 0, "the server's ledger reads serial 0");
        Assert_False(Get_HasVictimMarker(_VictimA), "A has no marker on the server");
        Assert_False(Get_HasVictimMarker(_VictimB), "B has no marker on the server");
        Request_DevourBegin(_VictimB);
        WaitUntil(n"Is_InSeize", n"OnServerInSeize", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInSeize(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_WatchSeconds, n"OnServerSeizeWatched");
    }

    UFUNCTION()
    private void OnServerSeizeWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Seize), "the server's devourer is still in Seize");
        Assert_True(Get_IsMarkedByDevourer(_VictimB), "B is held on the server");
        Assert_Equals_Int(_DevourEnds.Num(), 0, "the server raised no OnEnded");
        Hold_DevourServerRow(k_Row, _AfterBegin);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Devourer.Request_Begin(FMars_Request_Devour_Begin(_VictimA));
        WaitSeconds(k_DroppedSeconds, n"OnClientBeginWaited");
    }

    UFUNCTION()
    private void OnClientBeginWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AfterBegin = f"afterBegin=[phase {_Devourer.Get_Phase() :n} requests {Get_HasDevourRequests()} marked {Describe_Marked()} signals {_DevourPhases.Num()}/{_DevourEnds.Num()} serial {Get_DevourLedger().Serial}]";
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the client's devourer stayed Idle after its Begin");
        Assert_False(Get_HasDevourRequests(), "the client's devourer has no requests fragment after its Begin");
        Assert_False(Get_HasVictimMarker(_VictimA), "the client's copy of A is not marked");
        Assert_Equals_Int(_DevourPhases.Num() + _DevourEnds.Num(), 0, "the client's devourer raised no signal");
        Assert_Equals_Int(Get_DevourLedger().Serial, 0, "the client's ledger reads serial 0");
        WaitUntil(n"Is_InSeize", n"OnClientInSeize", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInSeize(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Devourer.Request_Cancel(FMars_Request_Devour_Cancel());
        WaitSeconds(k_DroppedSeconds, n"OnClientCancelWaited");
    }

    UFUNCTION()
    private void OnClientCancelWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_DevourRow(k_Row, _AfterBegin);
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Seize), "the client's devourer is still in Seize after its Cancel");
        Assert_True(Get_IsMarkedByDevourer(_VictimB), "the client's copy of B is marked");
        Assert_False(Get_HasDevourRequests(), "the client's devourer has no requests fragment after its Cancel");
        Assert_Equals_Int(_DevourEnds.Num(), 0, "the client raised no OnEnded");
        Finish_DevourRow();
    }
}
