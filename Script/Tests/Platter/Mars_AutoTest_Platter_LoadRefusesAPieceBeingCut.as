// A platter refuses a piece with a cut in flight. Filler slices of a plain box mesh, queued ahead of R's cut, keep R's slice
// waiting in RuntimeMesh's queue for several frames (it drains two per frame, first in first out), so R is Cutting when its
// load is issued and still Cutting when the platter drains it: the load step asserts at least two frames of fillers are
// still queued ahead. The platter refuses R Cutting (OnLoadRefused names R) and its books stay empty. The cut then resolves
// on its own: R is replaced by halves no platter holds, and nothing ever lands.
class UMars_AutoTest_Platter_LoadRefusesAPieceBeingCut : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(153000.0, -70000.0, -30000.0);
    // RuntimeMesh's queue holds sixteen: the fillers and R's slice fit.
    private const int32 k_FillerCount = 14;
    // Fillers still queued ahead of R's slice when the load is issued: two frames of RuntimeMesh drains, so the platter's
    // drain (in the pass after the load) answers while R is Cutting.
    private const int32 k_FillersAheadAtLoad = 4;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _R;
    private FCk_Handle_RuntimeMesh _Filler;
    private FCk_Handle _FillerOwner;
    private int32 _FillersResolved = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        _R = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        auto FillerEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Filler = utils_runtime_mesh::Add(FillerEntity, FCk_RuntimeMesh_Spec(Get_BoxMesh()));
        _FillerOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);

        Add_Step_WaitUntil("R and the filler mesh are Ready", n"Check_Ready", 0, 0);
        Add_Step("queue filler slices, then cut R", n"Step_QueueThenCut");
        Add_Step_WaitUntil("R's cut is in flight", n"Check_RCutting", 0, 0);
        Add_Step("load R onto the platter while its slice waits behind the fillers", n"Step_LoadWhileCutting");
        Add_Step_WaitUntil("the platter answered R's load", n"Check_RAnswered", 0, 0);
        Add_Step("R is refused Cutting and the platter's books are unchanged", n"Step_AssertRefusedCutting");
        Add_Step_WaitUntil("R's cut and every filler resolved", n"Check_AllResolved", 0, 0);
        Add_Step("R was cut into halves no platter holds, and nothing landed", n"Step_AssertCutOffThePlatter");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_R) && utils_runtime_mesh::Get_SetupState(_Filler) == ECk_RuntimeMesh_SetupState::Ready);
    }

    UFUNCTION()
    private void Step_QueueThenCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < k_FillerCount; ++Index)
        {
            auto Slice = FCk_Request_RuntimeMesh_Slice();
            Slice.Set_OperationID(FGuid::NewGuid());
            Slice.Set_ResultOwner(_FillerOwner);
            Slice.Set_Plane(Make_Plane(Get_BoundsCenter(_R), FVector::ForwardVector));
            utils_runtime_mesh::Request_Slice(_Filler, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnFillerResolved"));
        }

        Assert_Equals_Int(_FillersResolved, 0, "every filler slice was queued, none rejected on submission");
        Cut(_R, Get_BoundsCenter(_R), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_RCutting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_R.Get_IsCutting() || _Cuts.Num() > 0);
    }

    UFUNCTION()
    private void Step_LoadWhileCutting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 0, "R's cut has not resolved before the load");
        Assert_True(_R.Get_Status() == EMars_FoodPiece_Status::Cutting, f"R is Cutting when its load is issued (got {_R.Get_Status() :n})");
        Assert_True(k_FillerCount - _FillersResolved >= k_FillersAheadAtLoad,
            f"at least {k_FillersAheadAtLoad} filler slices are still queued ahead of R's ({k_FillerCount - _FillersResolved} are)");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is empty before R's load");

        Load(_Platter, _R);
    }

    // A refusal is never deferred: the drain answers it, or accepts R onto the books.
    UFUNCTION()
    private void Check_RAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AllRefusalCount(_Platter) > 0 || _Platter.Get_Occupancy() > 0);
    }

    UFUNCTION()
    private void Step_AssertRefusedCutting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Platter_LoadRefusal> Refusals;
        for (const auto& Event : _Refused)
        {
            if (Event.Platter == _Platter && Event.Piece == _R)
            { Refusals.Add(Event.Refusal); }
        }

        Assert_Equals_Int(Refusals.Num(), 1, "the platter answered R's load with one refusal");
        if (Refusals.Num() == 1)
        { Assert_True(Refusals[0] == EMars_Platter_LoadRefusal::Cutting, f"R is refused Cutting (got {Refusals[0] :n})"); }

        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 1, "the platter refused nothing but R");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the platter holds nothing");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 0, "nothing waits to drop");
        Assert_True(ck::Is_NOT_Valid(_R.TryGet_Platter()), "the refused R carries no platter");
    }

    UFUNCTION()
    private void Check_AllResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() > 0 && _FillersResolved == k_FillerCount);
    }

    UFUNCTION()
    private void Step_AssertCutOffThePlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cuts.Num(), 1, "R's cut resolved once");
        const auto IsCut = _Cuts.Num() == 1 && _Cuts[0].Outcome == EMars_FoodPiece_CutOutcome::Cut;
        Assert_True(IsCut, "R was cut");
        if (IsCut)
        {
            Assert_True(ck::Is_NOT_Valid(_Cuts[0].Positive.TryGet_Platter()) && ck::Is_NOT_Valid(_Cuts[0].Negative.TryGet_Platter()),
                "R's halves are born on no platter");
        }

        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is still empty");
        Assert_Equals_Int(Get_LoadedCount(_Platter), 0, "nothing landed on the platter");
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 1, "R's load was the platter's only refusal");
    }

    UFUNCTION()
    private void OnFillerResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        ++_FillersResolved;
    }
}
