// In the continuation in which the server first finds its empty board, it asks for a cut through the station root, a turn
// and a sweep with no cap: one answer with nothing straddling, one turn, one NothingFree. Three seconds later it sweeps
// again. The client starts counting what its copy raises only once its ledger reads each serial at 1 (a listener that
// arrives after those answers): from then on it sees the second refused sweep once and none of the earlier answers again.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 208000.0;
    private const float32 k_ClientWatchSeconds = 1.0f;
    private const float32 k_ServerStepSeconds = 3.0f;
    private const float32 k_ServerWatchSeconds = 3.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BoardRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BoardRigStationFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBoardStation();
        WaitUntil(n"Is_BoardRigStationFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(Make_PlaneThroughRoot(FVector::ForwardVector)));
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(90.0f));
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        WaitUntil(n"Is_ServerAnswered", n"OnServerAnswered", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_CutIssues.Num() >= 1 && _Turns.Num() >= 1 && _ReleaseRefusals.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerAnswered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_CutIssues.Num() == 1 && _CutIssues[0].Straddling == 0, f"the server answered one cut with nothing straddling (got [{Describe_Issues()}])");
        Assert_Equals_Int(_Turns.Num(), 1, "the server turned once");
        Assert_True(_ReleaseRefusals.Num() == 1 && _ReleaseRefusals[0] == EMars_FoodBoard_ReleaseRefusal::NothingFree,
            f"the server refused one sweep NothingFree (got [{Describe_Refusals()}])");
        WaitSeconds(k_ServerStepSeconds, n"OnServerSweepAgain");
    }

    UFUNCTION()
    private void OnServerSweepAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_ReleaseRefusals.Num() == 2 && _ReleaseRefusals[1] == EMars_FoodBoard_ReleaseRefusal::NothingFree,
            f"the server refused a second sweep NothingFree (got [{Describe_Refusals()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"answers=[{Describe_Issues()}] turns={_Turns.Num()} refusals=[{Describe_Refusals()}] ledger {Describe_Ledger(_Board.Get_Ledger())}");
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientLedgerAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ledger = _Board.Get_Ledger();
        auto Result = OutResult;
        Result.Set(Ledger.CutSerial == 1 && Ledger.TurnSerial == 1 && Ledger.ReleaseRefusalSerial >= 1);
    }

    UFUNCTION()
    private void Is_ClientLedgerSweptAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Board.Get_Ledger().ReleaseRefusalSerial == 2);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientLedgerAnswered", n"OnClientLedgerAnswered", k_SlowPolls);
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerAnswered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Board.Get_Ledger().ReleaseRefusalSerial, 1, "the client started counting before the second sweep");
        Clear_BoardRecord();
        WaitUntil(n"Is_ClientLedgerSweptAgain", n"OnClientLedgerSweptAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLedgerSweptAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Board.Get_Ledger();
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::CutIssued), 0, "the client raised no earlier answer again");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::Turned), 0, "the client raised no earlier turn again");
        Assert_True(_ReleaseRefusals.Num() == 1 && _ReleaseRefusals[0] == EMars_FoodBoard_ReleaseRefusal::NothingFree,
            f"the client raised the second refused sweep once, NothingFree (got [{Describe_Refusals()}])");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::HeldCountChanged), 0, "the client raised no count change");
        Assert_True(Ledger.CutSerial == 1 && Ledger.TurnSerial == 1 && Ledger.ReleaseRefusalSerial == 2,
            f"the client's ledger reads one answer, one turn and two refused sweeps ({Describe_Ledger(Ledger)})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the client reads no held piece");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"ledger {Describe_Ledger(Ledger)}");
        End_Client();
    }
}
