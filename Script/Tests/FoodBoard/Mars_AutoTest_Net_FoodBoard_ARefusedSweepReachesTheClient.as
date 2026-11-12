// The server's empty board is asked for a sweep capped at none, and 1.5 s later for one with no cap: it refuses NoRoom,
// then NothingFree, and the client raises the same two refusals in that order.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_ARefusedSweepReachesTheClient
class UCk_AutoTest_Net_FoodBoard_ARefusedSweepReachesTheClient : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 204000.0;

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

    private bool Get_AreRefusalsAsExpected()
    {
        return _ReleaseRefusals.Num() == 2 && _ReleaseRefusals[0] == EMars_FoodBoard_ReleaseRefusal::NoRoom
            && _ReleaseRefusals[1] == EMars_FoodBoard_ReleaseRefusal::NothingFree;
    }

    protected void On_ServerBoardReady() override
    {
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>(0)));
        WaitSeconds(constants_foodboard_net_autotest::k_StepSeconds, n"OnServerSecondSweep");
    }

    UFUNCTION()
    private void OnServerSecondSweep(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
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
        Assert_True(Get_AreRefusalsAsExpected(), f"the server refused NoRoom then NothingFree (got [{Describe_Refusals()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"refusals=[{Describe_Refusals()}]");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_AreRefusalsAsExpected(), f"the client raised NoRoom then NothingFree (got [{Describe_Refusals()}])");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"refusals=[{Describe_Refusals()}]");
        End_Client();
    }
}
