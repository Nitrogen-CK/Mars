// The server slices the meat slab by hand through its centre, destroys the slab, and a step later spawns both halves in one
// frame. On the client no frame shows a piece standing with one it was cut from, and both halves stand within a few
// frames of the first piece entity appearing. The frames in which nothing stood are logged (the slab's place is empty
// until the halves are built).
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheSourcesEndThenTheHalves
class UCk_AutoTest_Net_FoodPiece_TheSourcesEndThenTheHalves : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 181000.0;
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const int32 k_MaxStandFrames = 12;

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
        Destroy_Whole();
        WaitSeconds(k_StepSeconds, n"OnServerSpawnHalves");
    }

    UFUNCTION()
    private void OnServerSpawnHalves(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_P();
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
        Result.Set(ck::Is_NOT_Valid(Find_FoodPieceNear(_FloorTop)) && Get_StandingNear(_FloorTop).Num() == 2);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();

        // The first piece script's appearance to the last half's first standing frame.
        auto FirstAppear = -1;
        auto LastStood = -1;
        for (auto Entity : Get_PieceEntitiesNear(_FloorTop))
        {
            const auto Sighting = Get_Sighting(Entity);
            if (FirstAppear < 0 || Sighting.AppearFrame < FirstAppear)
            { FirstAppear = Sighting.AppearFrame; }

            if (Sighting.StoodFrame > LastStood)
            { LastStood = Sighting.StoodFrame; }
        }

        const auto StandFrames = LastStood - FirstAppear;
        Assert_Equals_Int(_Both, 0, "no frame shows a piece standing with one it was cut from");
        Assert_Equals_Int(Get_Tally().MeshImports, 1, "with no whole food left to share from, the replay loads the mesh once");
        Assert_True(FirstAppear >= 0 && StandFrames <= k_MaxStandFrames, f"both halves stand within {k_MaxStandFrames} frames of the first piece entity (took {StandFrames})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} standFrames={StandFrames} {Describe_Tally()}");
        End_Client();
    }
}
