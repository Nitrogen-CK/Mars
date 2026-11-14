// The server spawns a board station that, as it composes, asks a cut through its origin, a turn and an uncapped sweep:
// its drain answers one cut with nothing straddling, one turn and one NothingFree in the spawn frame. Three seconds
// after it finds the station it sweeps again. The client's copy is born into the three answers: it raises none of them,
// then the second refused sweep once, and its ledger reads one answer, one turn and two refused sweeps.
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
        Spawn_ServerBoardStationOfClass(UMars_TESTONLY_NetBoardStation_BornAnswered_EntityScript);
        WaitUntil(n"Is_BoardRigStationFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerStepSeconds, n"OnServerSweepAgain");
    }

    UFUNCTION()
    private void OnServerSweepAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Board.Get_Ledger();
        Assert_True(Ledger.CutSerial == 1 && Ledger.TurnSerial == 1 && Ledger.ReleaseRefusalSerial == 1,
            f"the station answered once of each kind as it composed ({Describe_Ledger(Ledger)})");
        Assert_True(Ledger.LastCut.Straddling == 0, f"the answered cut straddled nothing ({Describe_Issue(Ledger.LastCut)})");
        Assert_True(Ledger.LastReleaseRefusal == EMars_FoodBoard_ReleaseRefusal::NothingFree,
            f"the refused sweep is NothingFree (got {Ledger.LastReleaseRefusal :n})");
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    // Whether the server's rig bound before or after the spawn frame's drain, it recorded each answer its ledger counts
    // past the ledger it found.
    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Board.Get_Ledger();
        Assert_Equals_Int(_ReleaseRefusals.Num(), Ledger.ReleaseRefusalSerial - _FoundLedger.ReleaseRefusalSerial,
            f"the server recorded each refused sweep after it found its station (got [{Describe_Refusals()}])");
        Assert_True(_ReleaseRefusals.Num() > 0 && _ReleaseRefusals.Last() == EMars_FoodBoard_ReleaseRefusal::NothingFree,
            f"the server refused a second sweep NothingFree (got [{Describe_Refusals()}])");
        Assert_True(Ledger.CutSerial == 1 && Ledger.TurnSerial == 1 && Ledger.ReleaseRefusalSerial == 2,
            f"the server's ledger reads one answer, one turn and two refused sweeps ({Describe_Ledger(Ledger)})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"answers=[{Describe_Issues()}] turns={_Turns.Num()} refusals=[{Describe_Refusals()}] ledger {Describe_Ledger(Ledger)}");
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientLedgerSweptAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBoardStationFound() && _Board.Get_Ledger().ReleaseRefusalSerial == 2);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientLedgerSweptAgain", n"OnClientLedgerSweptAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLedgerSweptAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    // Each kind raised = what the ledger counts now less what the first notify carried.
    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Board.Get_Ledger();
        const auto First = Get_FirstNotifyLedger();
        Log_BoardResult(f"ledger {Describe_Ledger(Ledger)} first@{Get_FirstNotifyFrame()} ({Describe_Ledger(First)}) refusals=[{Describe_Refusals()}]");

        Assert_True(Get_BoardInitialState() == EMars_Net_InitialState::Taken, "the client's copy took the state it was born into");
        Assert_True(_InitialAtFind == EMars_Net_InitialState::Awaited, "the client found its copy before its ledger's first application");
        Assert_True(Get_HasFirstNotify(), "the client recorded a rep-notify of its copy's ledger");
        Assert_Equals_Int(First.CutSerial, 1, "the first notify carried the cut the station was born into");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::CutIssued), Ledger.CutSerial - First.CutSerial,
            "the client raised only the cuts after its first notify");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::Turned), Ledger.TurnSerial - First.TurnSerial,
            "the client raised only the turns after its first notify");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::ReleaseRefused),
            Ledger.ReleaseRefusalSerial - First.ReleaseRefusalSerial, "the client raised only the refused sweeps after its first notify");

        auto RefusalsAfterFirst = 0;
        for (int32 Index = 0; Index < _Events.Num(); ++Index)
        {
            if (_Events[Index] == EMars_TESTONLY_NetBoardEvent::ReleaseRefused && _EventFrames[Index] > Get_FirstNotifyFrame())
            { ++RefusalsAfterFirst; }
        }

        Assert_True(_ReleaseRefusals.Num() > 0 && _ReleaseRefusals.Last() == EMars_FoodBoard_ReleaseRefusal::NothingFree,
            f"the client's last refused sweep is NothingFree (got [{Describe_Refusals()}])");
        Assert_Equals_Int(RefusalsAfterFirst, _ReleaseRefusals.Num(), "every refused sweep the client raised came after its first notify's frame");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::HeldCountChanged), 0, "the client raised no count change");
        Assert_True(Ledger.CutSerial == 1 && Ledger.TurnSerial == 1 && Ledger.ReleaseRefusalSerial == 2,
            f"the client's ledger reads one answer, one turn and two refused sweeps ({Describe_Ledger(Ledger)})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the client reads no held piece");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        End_Client();
    }
}
