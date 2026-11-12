// The server slices the meat slab by hand through its centre and spawns both halves in one frame, then destroys the slab.
// The client samples every frame: no frame shows a piece standing with one it was cut from, and from the first frame the
// slab stood something always stands. While the slab is still alive and both halves stand, it reads Superseded and both
// halves wear a display.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_HalvesThenTheSourcesEnd
class UCk_AutoTest_Net_FoodPiece_HalvesThenTheSourcesEnd : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 180000.0;
    private const float32 k_ServerWatchSeconds = 4.0f;

    // Client: frames in which the slab was alive and both halves stood, and of those the ones that broke the rule.
    private int32 _AliveWithHalvesFrames = 0;
    private int32 _AliveWithHalvesBad = 0;

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
        Spawn_N();
        WaitSeconds(k_StepSeconds, n"OnServerDestroyWhole");
    }

    UFUNCTION()
    private void OnServerDestroyWhole(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Destroy_Whole();
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Get_ReadyPieceCountNear(_FloorTop)}");
        End_Server();
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        const auto Whole = Find_FoodPieceNear(_FloorTop);
        TArray<FCk_Handle_FoodPiece> Halves;
        for (const auto& Piece : InStanding)
        {
            if (Piece.Get_IsWhole() == false)
            { Halves.Add(Piece); }
        }

        if (ck::Is_NOT_Valid(Whole) || Halves.Num() < 2)
        { return; }

        ++_AliveWithHalvesFrames;
        FCk_Handle HalfA = Halves[0];
        FCk_Handle HalfB = Halves[1];
        if (Get_IsSuperseded(Whole) == false || HalfA.Is_RuntimeMeshDisplay() == false || HalfB.Is_RuntimeMeshDisplay() == false)
        { ++_AliveWithHalvesBad; }
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
        Assert_Equals_Int(_Both, 0, "no frame shows a piece standing with one it was cut from");
        Assert_Equals_Int(_Neither, 0, "something stands in every frame from the slab's first");
        Assert_True(_AliveWithHalvesFrames > 0, "the slab was still alive while both halves stood");
        Assert_Equals_Int(_AliveWithHalvesBad, 0, "while alive with both halves standing the slab reads Superseded and both halves wear a display");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} aliveWithHalves={_AliveWithHalvesFrames} bad={_AliveWithHalvesBad} {Describe_Tally()}");
        End_Client();
    }
}
