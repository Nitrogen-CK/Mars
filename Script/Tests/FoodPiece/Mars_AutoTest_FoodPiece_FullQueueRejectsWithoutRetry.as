// A cut submitted while RuntimeMesh's world-wide queue is full is rejected on submission (RejectedLimit) and resolves at
// once as Rejected: the piece is Ready, not cutting and out of the ledger, and the cut is not retried. Filler slices of a
// plain box mesh fill the queue, and each filler that resolves queues another, so the queue is still full when the
// piece's drain submits. Once the fillers stop and drain, the same piece cuts.
class UMars_AutoTest_FoodPiece_FullQueueRejectsWithoutRetry : UMars_AutoTestRig_FoodPiece
{
    // RuntimeMesh's queue capacity.
    private int32 _QueueCapacity = 16;

    private FCk_Handle_FoodPiece _Source;
    private FCk_Handle_RuntimeMesh _Filler;
    private FCk_Handle _FillerOwner;
    private bool _IsToppingUp = false;
    private int32 _FillersQueued = 0;
    private int32 _FillersResolved = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Source = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -41100.0)), Make_Spec(1.0));

        auto FillerEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Filler = utils_runtime_mesh::Add(FillerEntity, FCk_RuntimeMesh_Spec(Get_BoxMesh()));
        _FillerOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);

        Add_Step_WaitUntil("the piece and the filler mesh are Ready", n"Check_Ready");
        Add_Step("fill the queue, keep it full, and cut the piece", n"Step_FillThenCut");
        Add_Step_WaitUntil("the cut resolved", n"Check_OneResolved");
        Add_Step("the cut was rejected and the piece is whole; stop the fillers", n"Step_AssertRejected");
        Add_Step_WaitUntil("every filler resolved", n"Check_FillersDrained");
        Add_Step("no retry happened; cut the piece again", n"Step_AssertNoRetryAndCut");
        Add_Step_WaitUntil("the second cut resolved", n"Check_TwoResolved");
        Add_Step("the second cut succeeded", n"Step_AssertCut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Source) && utils_runtime_mesh::Get_SetupState(_Filler) == ECk_RuntimeMesh_SetupState::Ready);
    }

    UFUNCTION()
    private void Step_FillThenCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _IsToppingUp = true;
        for (int32 Index = 0; Index < _QueueCapacity; ++Index)
        { QueueFiller(); }

        Assert_Equals_Int(_FillersResolved, 0, "the queue took every filler: it was empty before the test");
        Cut(_Source, Get_BoundsCenter(_Source), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_OneResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _IsToppingUp = false;

        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Rejected, f"the cut is Rejected (got {Result.Outcome :n})");
        Assert_True(Result.SliceOutcome.IsSet() && Result.SliceOutcome.GetValue() == ECk_RuntimeMesh_SliceOutcome::RejectedLimit, "the full queue rejected the slice");
        Assert_True(_Source.Get_Status() == EMars_FoodPiece_Status::Ready, f"the piece is Ready again (got {_Source.Get_Status() :n})");
        Assert_False(_Source.Get_IsCutting(), "the piece is not cutting");
        Assert_False(utils_foodpiece::Get_HasPendingCut(ck::TransientEntity(), _Source), "the ledger let go of the rejected cut");
    }

    UFUNCTION()
    private void Check_FillersDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FillersResolved == _FillersQueued);
    }

    UFUNCTION()
    private void Step_AssertNoRetryAndCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "the rejected cut was not retried");
        Assert_False(_Source.Get_IsCutting(), "the piece is still not cutting");
        Cut(_Source, Get_BoundsCenter(_Source), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_TwoResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Cuts[1].Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the second cut succeeded (got {_Cuts[1].Outcome :n})");
    }

    private void QueueFiller()
    {
        ++_FillersQueued;

        auto Slice = FCk_Request_RuntimeMesh_Slice();
        Slice.Set_OperationID(FGuid::NewGuid());
        Slice.Set_ResultOwner(_FillerOwner);
        Slice.Set_Plane(Make_Plane(Get_BoundsCenter(_Source), FVector::ForwardVector));
        utils_runtime_mesh::Request_Slice(_Filler, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnFillerResolved"));
    }

    // A filler that ran frees a queue slot; the next takes it so the queue stays full. A rejected filler queues nothing.
    UFUNCTION()
    private void OnFillerResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        ++_FillersResolved;

        if (_IsToppingUp && InResult.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded)
        { QueueFiller(); }
    }
}
