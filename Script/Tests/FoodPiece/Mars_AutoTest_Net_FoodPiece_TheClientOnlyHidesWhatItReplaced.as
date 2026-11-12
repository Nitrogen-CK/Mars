// The server slices the meat slab by hand through its centre, spawns both halves in one frame and destroys the slab a step
// later. Every frame, every piece of the server's world reads Current. On the client the superseded slab is still a valid,
// Ready FoodPiece whose world item holds its item in every frame it is alive, it is still alive and superseded when the
// server's report (sent before the slab's destruction) arrives, and no client piece has a Jolt body.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_TheClientOnlyHidesWhatItReplaced
class UCk_AutoTest_Net_FoodPiece_TheClientOnlyHidesWhatItReplaced : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 189000.0;
    private const float32 k_ServerWatchSeconds = 4.0f;

    // Server: frames in which one of its pieces did not read Current.
    private int32 _NotCurrent = 0;
    // Client: frames in which the slab was alive and superseded, the ones in which it was not a Ready FoodPiece holding its
    // item, frames in which a piece had a body, and whether the slab was alive and superseded when the report arrived.
    private int32 _SupersededFrames = 0;
    private int32 _SupersededBad = 0;
    private int32 _BodyFrames = 0;
    private TOptional<bool> _AliveAtReport;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        Begin_Sampling(InHandle);
        if (Get_IsServer() == false)
        {
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
        WaitSeconds(k_StepSeconds * 0.5f, n"OnServerReport");
    }

    UFUNCTION()
    private void OnServerReport(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_PieceReport(Get_PieceReport());
        WaitSeconds(k_StepSeconds * 0.5f, n"OnServerDestroyWhole");
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
        End_Sampling();
        Assert_True(_SampleFrame > 0, "the server sampled");
        Assert_Equals_Int(_NotCurrent, 0, "every piece of the server's world reads Current in every frame");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} notCurrent={_NotCurrent} pieces={Get_ReadyPieceCountNear(_FloorTop)}");
        End_Server();
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (Get_IsServer())
        {
            for (auto Entity : InEntities)
            {
                if (Entity.Is_FoodPiece() && Entity.As_FoodPiece().Get_Standing() != EMars_FoodPiece_Standing::Current)
                {
                    ++_NotCurrent;
                    return;
                }
            }

            return;
        }

        for (auto Entity : InEntities)
        {
            if (Entity.Is_JoltBody())
            {
                ++_BodyFrames;
                break;
            }
        }

        const auto Whole = Find_FoodPieceNear(_FloorTop);
        const auto IsSuperseded = ck::IsValid(Whole) && Get_IsSuperseded(Whole);
        if (_AliveAtReport.IsSet() == false && Get_PieceReport().Serial >= 1)
        { _AliveAtReport = TOptional<bool>(IsSuperseded); }

        if (IsSuperseded == false)
        { return; }

        ++_SupersededFrames;
        FCk_Handle Entity = Whole;
        const auto HoldsItem = Entity.Is_WorldItem() && ck::IsValid(Entity.As_WorldItem().Get_Item());
        if (Whole.Get_Status() != EMars_FoodPiece_Status::Ready || HoldsItem == false)
        { ++_SupersededBad; }
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
        const auto AliveAtReport = _AliveAtReport.IsSet() && _AliveAtReport.GetValue();
        Assert_True(_SupersededFrames > 0, "the slab was alive and superseded");
        Assert_Equals_Int(_SupersededBad, 0, "while superseded the slab is a Ready FoodPiece whose world item holds its item");
        Assert_True(AliveAtReport, "the slab was alive and superseded when the report sent before its destruction arrived");
        Assert_Equals_Int(_BodyFrames, 0, "no client piece has a Jolt body");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} superseded={_SupersededFrames} bad={_SupersededBad} aliveAtReport={AliveAtReport} bodies={_BodyFrames} {Describe_Tally()}");
        End_Client();
    }
}
