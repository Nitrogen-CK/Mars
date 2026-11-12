// The server spawns the meat slab and cuts it through its centre in the frame its piece becomes Ready, before its ledger
// can have reached the client. The client ends with the slab gone and two standing halves; the frames that showed both and
// the frames that showed neither are logged (a food cut before its lineage reached a client may stand with its halves
// until its ledger or its destruction arrives).
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AFoodCutAsSoonAsItIsReady
class UCk_AutoTest_Net_FoodPiece_AFoodCutAsSoonAsItIsReady : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 186000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            WaitUntil(n"Is_ClientSettled", n"OnClientSettled", k_SlowPolls);
            return;
        }

        Begin_ServerFloor(InHandle);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_ServerSlabReady", n"OnServerSlabReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rock) && _Rock.Is_FoodPiece() && _Rock.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void OnServerSlabReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cut(_Rock.As_FoodPiece(), Make_CentrePlane());
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut), 1, "the slab was cut");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"cuts={Get_CutCount(EMars_FoodPiece_CutOutcome::Cut)} pieces={Get_ReadyPieceCountNear(_FloorTop)}");
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(Find_FoodPieceNear(_FloorTop)) && Get_StandingNear(_FloorTop).Num() == 2);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();
        Assert_Equals_Int(Get_StandingNear(_FloorTop).Num(), 2, "two halves stand");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} wholeStood={_WholeStood} {Describe_Tally()}");
        End_Client();
    }
}
