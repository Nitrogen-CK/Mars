// The server slices the meat slab by hand through its centre and spawns, in one frame, the negative half as it is and the
// positive half with its recipe's plane replaced by one at (1000, 0, 0) that misses the slab (and a lineage of its own);
// a step later it destroys the slab. On the client the positive half's replay fails: its entity is not a FoodPiece and shows a stand-in within 2 s of
// the failure. A stand-in supersedes nothing: the slab reads Current until the negative half is built, then Superseded;
// the negative half stands.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AFailedReplayShowsAStandIn
class UCk_AutoTest_Net_FoodPiece_AFailedReplayShowsAStandIn : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 187000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float64 k_MaxStandInSeconds = 2.0;

    // Client: the entity whose replay failed, when it failed and when its stand-in appeared; frames in which the living
    // slab's standing broke the rule before and after the negative half was built.
    private FCk_Handle _Failed;
    private TOptional<float64> _FailedAt;
    private TOptional<float64> _StandInAt;
    private int32 _BeforeBad = 0;
    private int32 _AfterFrames = 0;
    private int32 _AfterBad = 0;

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
        const auto Missing = Make_Plane(FVector(1000.0, 0.0, 0.0), FVector::ForwardVector, FVector::RightVector);
        // Its own lineage: within one lineage the client's memo slices the root once, and a root cut along the missing
        // plane would refuse the negative half's cut too.
        auto Unbuildable = Make_ByHandBirth(_WholeSpec, _ByHandSlices[0], FMars_FoodPiece_RecipeCut(Missing, EMars_FoodPiece_CutSide::Positive));
        Unbuildable.Spec.Data.Lineage = FGuid::NewGuid();
        Spawn_N();
        Spawn_ByHand(Unbuildable);
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
        Assert_Equals_Int(Get_ReadyPieceCountNear(_FloorTop), 2, "both of the server's pieces are Ready");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Get_ReadyPieceCountNear(_FloorTop)}");
        End_Server();
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        for (auto Entity : Get_PieceEntitiesNear(_FloorTop))
        {
            const auto Replay = utils_foodpiece::TryGet_ReplayResult(Entity);
            if (ck::Is_NOT_Valid(_Failed) && Replay.IsSet() && Replay.GetValue().State == EMars_FoodPiece_ReplayState::Failed)
            {
                _Failed = Entity;
                _FailedAt = TOptional<float64>(Get_Now());
            }
        }

        if (ck::IsValid(_Failed) && _StandInAt.IsSet() == false && ck::IsValid(utils_food::TryGet_StandIn(_Failed)))
        { _StandInAt = TOptional<float64>(Get_Now()); }

        const auto Whole = Find_FoodPieceNear(_FloorTop);
        if (ck::Is_NOT_Valid(Whole))
        { return; }

        const auto Negative = Find_ByKept(Get_PieceEntitiesNear(_FloorTop), EMars_FoodPiece_CutSide::Negative);
        const auto IsBuilt = ck::IsValid(Negative) && Negative.Is_FoodPiece() && Negative.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready;
        const auto Standing = Get_StandingOf(Whole);
        if (IsBuilt == false)
        {
            if (Standing.IsSet() && Standing.GetValue() != EMars_FoodPiece_Standing::Current)
            { ++_BeforeBad; }

            return;
        }

        ++_AfterFrames;
        if (Get_IsSuperseded(Whole) == false)
        { ++_AfterBad; }
    }

    UFUNCTION()
    private void Is_ClientSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_WholeStood && ck::Is_NOT_Valid(Find_FoodPieceNear(_FloorTop)) && Get_StandingNear(_FloorTop).Num() == 1
            && ck::IsValid(_Failed) && (_StandInAt.IsSet() || Get_Now() - _FailedAt.GetValue() > k_MaxStandInSeconds));
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();
        const auto StandInSeconds = _StandInAt.IsSet() ? _StandInAt.GetValue() - _FailedAt.GetValue() : -1.0;
        const auto Negative = Find_ByKept(Get_PieceEntitiesNear(_FloorTop), EMars_FoodPiece_CutSide::Negative);

        Assert_False(_Failed.Is_FoodPiece(), "the failed replay's entity is not a FoodPiece");
        Assert_True(_StandInAt.IsSet() && StandInSeconds <= k_MaxStandInSeconds, f"a stand-in appeared within {k_MaxStandInSeconds} s of the failure (took {StandInSeconds})");
        Assert_Equals_Int(_BeforeBad, 0, "the slab reads Current until the negative half is built");
        Assert_True(_AfterFrames > 0, "the slab was alive once the negative half was built");
        Assert_Equals_Int(_AfterBad, 0, "once the negative half is built the slab reads Superseded");
        Assert_True(Get_Stands(Negative), "the negative half stands");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} standInSeconds={StandInSeconds} before={_BeforeBad} after={_AfterFrames} bad={_AfterBad} {Describe_Tally()}");
        End_Client();
    }
}
