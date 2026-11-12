// The server slices the meat slab's geometry by hand through its centre and spawns one real half whose recipe records the
// cut at position (1000, 0, 0), normal +X, a plane that misses the slab. The server's piece is Ready. On the client the
// replay resolves Failed (SliceRejected, NoIntersection): the entity is not a FoodPiece and wears no display, and the
// client counted one failed replay.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_AReplayThatCannotBeBuiltLeavesNoPiece
class UCk_AutoTest_Net_FoodPiece_AReplayThatCannotBeBuiltLeavesNoPiece : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 177000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;

    private FCk_Handle _Half;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReplayResolved", n"OnClientReplayResolved", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    protected void On_ServerSlabStill() override
    {
        auto Slab = _Rock.As_FoodPiece();
        Slice_ByHand(Slab.Get_Geometry(), Make_CentrePlane(), Slab.Get_Cap());
        WaitUntil(n"Is_ServerSliced", n"OnServerSliced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSliced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ByHandSlices.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerSliced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Slice = _ByHandSlices[0];
        Assert_True(Slice.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded, f"the slice succeeded (got {Slice.Get_Outcome() :n})");
        if (Slice.Get_Outcome() != ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
            return;
        }

        const auto Missing = Make_Plane(FVector(1000.0, 0.0, 0.0), FVector::ForwardVector, FVector::RightVector);
        _Half = Spawn_ByHand(Make_ByHandBirth(Make_SourceSpec(_Rock.As_FoodPiece()), Slice, FMars_FoodPiece_RecipeCut(Missing, EMars_FoodPiece_CutSide::Positive)));
        utils_entity_lifetime::Request_DestroyEntity(Slice.Get_Negative());
        WaitUntil(n"Is_ServerHalfReady", n"OnServerHalfReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHalfReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_ReadyPieceCountNear(_FloorTop) == 1);
    }

    UFUNCTION()
    private void OnServerHalfReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ready = ck::IsValid(_Half) && _Half.Is_FoodPiece() && _Half.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready;
        Assert_True(Ready, "the server's piece is Ready");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"ready={Ready} {Describe_Tally()}");
        WaitSeconds(k_ServerWatchSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Server();
    }

    UFUNCTION()
    private void Is_ClientReplayResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Resolved = false;
        for (auto Entity : Get_PieceEntitiesNear(_FloorTop))
        {
            const auto Replay = utils_foodpiece::TryGet_ReplayResult(Entity);
            if (Replay.IsSet() && Replay.GetValue().State != EMars_FoodPiece_ReplayState::Waiting)
            { Resolved = true; }
        }

        auto Result = OutResult;
        Result.Set(Resolved);
    }

    UFUNCTION()
    private void OnClientReplayResolved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pieces = Get_PieceEntitiesNear(_FloorTop);
        Assert_Equals_Int(Pieces.Num(), 1, "one piece entity on the client");
        if (Pieces.Num() == 0)
        {
            End_Client();
            return;
        }

        const auto Entity = Pieces[0];
        const auto Replay = utils_foodpiece::TryGet_ReplayResult(Entity).GetValue();
        Assert_True(Replay.State == EMars_FoodPiece_ReplayState::Failed, f"the replay failed (got {Replay.State :n})");
        Assert_True(Replay.Failure == EMars_FoodPiece_ReplayFailure::SliceRejected, f"a slice was rejected (got {Replay.Failure :n})");
        const auto Outcome = Replay.SliceOutcome.IsSet() ? Replay.SliceOutcome.GetValue() : ECk_RuntimeMesh_SliceOutcome::Succeeded;
        Assert_True(Replay.SliceOutcome.IsSet() && Outcome == ECk_RuntimeMesh_SliceOutcome::NoIntersection, f"the slice found no intersection (got {Outcome :n})");
        Assert_False(Entity.Is_FoodPiece(), "the entity is not a FoodPiece");
        Assert_False(Entity.Is_RuntimeMeshDisplay(), "the entity wears no display");

        const auto Tally = Get_Tally();
        Assert_Equals_Int(Tally.Failed, 1, "one replay failed");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"state={Replay.State :n} failure={Replay.Failure :n} slice={Outcome :n} foodPiece={Entity.Is_FoodPiece()} {Describe_Tally()}");
        End_Client();
    }
}
