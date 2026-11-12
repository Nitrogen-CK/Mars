// The server's empty board is asked, in one frame, for a sweep capped at none and one with no cap: it refuses NoRoom, then
// NothingFree, in one drain. The client raises a refusal twice, the last NothingFree (both carry the ledger's last value).
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised
class UCk_AutoTest_Net_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 205000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BoardRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            Await_ClientStep(1, n"OnClientStep1");
            return;
        }

        Begin_ServerBoardOnly(InHandle);
    }

    protected void On_ServerBoardReady() override
    {
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>(0)));
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        WaitUntil(n"Is_ServerRefusedTwice", n"OnServerRefusedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRefusedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ReleaseRefusals.Num() >= 2);
    }

    UFUNCTION()
    private void OnServerRefusedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        const auto IsExpected = _ReleaseRefusals.Num() == 2 && _ReleaseRefusals[0] == EMars_FoodBoard_ReleaseRefusal::NoRoom
            && _ReleaseRefusals[1] == EMars_FoodBoard_ReleaseRefusal::NothingFree;
        Assert_True(IsExpected, f"the server refused NoRoom then NothingFree (got [{Describe_Refusals()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"refusals=[{Describe_Refusals()}]");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsExpected = _ReleaseRefusals.Num() == 2 && _ReleaseRefusals[1] == EMars_FoodBoard_ReleaseRefusal::NothingFree;
        Assert_True(IsExpected, f"the client raised a refusal twice, the last NothingFree (got [{Describe_Refusals()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        // The refusals in order: the first's value is what one replication carried for both.
        Log_BoardResult(f"refusals=[{Describe_Refusals()}]");
        End_Client();
    }
}
