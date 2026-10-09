// Leaving mid-cut leaves one fresh joint and nothing of the old one. In the frame the board issues the chop's cut, filler
// slices are queued ahead of it (so it waits in RuntimeMesh's queue for several frames) and the operator leaves. Idle finds the
// board untouched but its joint mid-cut, clears it, and a fresh joint is built. The stale slice then resolves for a destroyed
// piece: the old joint resolves no cut, the board reports no committed cut, no piece of the old lineage survives, and the
// fresh joint is the station's only piece.
class UMars_AutoTest_DicingStation_LeaveMidCutLeavesOneFreshJoint : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(14400.0, -9000.0, -30000.0);
    // RuntimeMesh slices two a frame from a world queue of 16: seven frames of fillers before the joint's slice.
    private const int32 k_FillerCount = 14;

    private FCk_Handle_RuntimeMesh _Filler;
    private FCk_Handle _FillerOwner;
    private int32 _FillersQueued = 0;
    private int32 _FillersResolved = 0;
    private bool _LeaveOnIssue = false;
    private bool _InFlightWhenLeft = false;

    private FCk_Handle_FoodPiece _Joint;
    private FGuid _OldLineage;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin, mars::CuttableFood_MeatSlab_Mars);

        auto FillerEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Filler = utils_runtime_mesh::Add(FillerEntity, FCk_RuntimeMesh_Spec(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"))));
        _FillerOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);

        Add_Step_WaitUntil("the station composed its Dicing and FoodBoard", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the board holds one shown joint and the filler mesh is Ready", n"Check_Ready", 0, 10.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step("chop; when the cut is issued, queue fillers ahead of it and leave", n"Step_Chop");
        Add_Step_WaitUntil("every filler and the stale slice resolved, and a fresh joint is shown", n"Check_Settled", 0, 10.0f);
        Add_Step_WaitSeconds("a late commit of the stale cut would show in this window", 0.3f);
        Add_Step("one fresh joint; nothing of the old one", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && Get_AllHeldShown()
            && utils_runtime_mesh::Get_SetupState(_Filler) == ECk_RuntimeMesh_SetupState::Ready);
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Take();
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _Board.Get_Held()[0];
        _OldLineage = _Joint.Get_Lineage();
        Watch(_Joint);

        _LeaveOnIssue = true;
        Chop();
    }

    // The board has handed the joint its cut; the joint has not sliced yet. The fillers go ahead of its slice, and the
    // operator leaves in this very frame.
    protected void On_CutIssued(const FMars_FoodBoard_CutIssue& InIssue) override
    {
        if (_LeaveOnIssue == false)
        { return; }

        _LeaveOnIssue = false;
        _InFlightWhenLeft = InIssue.Issued == 1 && _Joint.Get_HasBoardCutPending();

        for (int32 Index = 0; Index < k_FillerCount; ++Index)
        {
            auto Slice = FCk_Request_RuntimeMesh_Slice();
            Slice.Set_OperationID(FGuid::NewGuid());
            Slice.Set_ResultOwner(_FillerOwner);
            auto Plane = FCk_RuntimeMesh_PlaneLocal();
            Plane.Set_PositionCm(FVector(5.0, 5.0, 5.0));
            Plane.Set_Normal(FVector::ForwardVector);
            Plane.Set_Tangent(FVector::UpVector);
            Slice.Set_Plane(Plane);
            utils_runtime_mesh::Request_Slice(_Filler, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnFillerResolved"));
            ++_FillersQueued;
        }

        Leave();
    }

    // The joint's slice no longer waits in the ledger once it resolved, stale or not.
    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto FreshShown = _Board.Get_HeldCount() == 1 && _Board.Get_Held()[0].Get_Lineage() != _OldLineage && Get_AllHeldShown();
        auto Res = OutResult;
        Res.Set(_FillersResolved == _FillersQueued && utils_foodpiece::Get_HasPendingCut(ck::TransientEntity(), _Joint) == false && FreshShown);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_InFlightWhenLeft, "the joint's cut was issued and in flight when the operator left");
        Assert_Equals_Int(_FillersQueued, k_FillerCount, "every filler slice was queued ahead of the joint's");
        Assert_Equals_Int(Get_OutcomeCountFor(_Joint), 0, "the cleared joint resolved no cut: its slice went stale");
        Assert_Equals_Int(_PieceCuts, 0, "the board reported no committed cut");
        Assert_True(ck::Is_NOT_Valid(_Joint), "the old joint is destroyed");
        Assert_Equals_Int(Get_LineageCount(_OldLineage), 0, "no piece of the old lineage survives");

        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "one joint is held");
        Assert_True(_Board.Get_IsUntouched(), "the fresh joint's board is untouched");
        Assert_Equals_Int(Get_StationPieces(false).Num(), 1, "the fresh joint is the station's only piece: no duplicate joint");
    }

    UFUNCTION()
    private void OnFillerResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        ++_FillersResolved;
    }
}
