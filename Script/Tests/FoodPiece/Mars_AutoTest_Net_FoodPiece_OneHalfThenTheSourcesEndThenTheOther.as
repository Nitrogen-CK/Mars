// The server slices the meat slab by hand through its centre and spawns the positive half, a step later destroys the slab,
// and a step later spawns the negative half. On the client no frame shows a piece standing with one it was cut from, the
// negative half stands within a few frames of its entity appearing, and the client sliced once.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_OneHalfThenTheSourcesEndThenTheOther
class UCk_AutoTest_Net_FoodPiece_OneHalfThenTheSourcesEndThenTheOther : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 183000.0;
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const int32 k_MaxStandFrames = 3;

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

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        Begin_ByHandHalves();
    }

    protected void On_ServerHalvesHeld() override
    {
        Spawn_P();
        WaitSeconds(k_StepSeconds, n"OnServerDestroyWhole");
    }

    UFUNCTION()
    private void OnServerDestroyWhole(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Destroy_Whole();
        WaitSeconds(k_StepSeconds, n"OnServerSpawnN");
    }

    UFUNCTION()
    private void OnServerSpawnN(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_N();
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Get_ReadyPieceCountNear(_FloorTop)}");
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_WholeStood && ck::Is_NOT_Valid(Find_FoodPieceNear(_FloorTop)) && Get_StandingNear(_FloorTop).Num() == 2);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();
        const auto Negative = Find_ByKept(Get_PieceEntitiesNear(_FloorTop), EMars_FoodPiece_CutSide::Negative);
        const auto Delay = Get_StandDelay(Negative);
        const auto DelayFrames = Delay.IsSet() ? Delay.GetValue() : -1;
        const auto Tally = Get_Tally();

        Assert_Equals_Int(_Both, 0, "no frame shows a piece standing with one it was cut from");
        Assert_True(Delay.IsSet() && DelayFrames <= k_MaxStandFrames, f"the negative half stands within {k_MaxStandFrames} frames of its entity appearing (took {DelayFrames})");
        Assert_Equals_Int(Tally.Slices, 1, "the client sliced once");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} negativeStandFrames={DelayFrames} {Describe_Tally()}");
        End_Client();
    }
}
