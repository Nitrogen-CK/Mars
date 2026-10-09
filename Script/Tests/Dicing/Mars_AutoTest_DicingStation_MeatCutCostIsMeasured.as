// What a cut of the 636-triangle meat slab costs, measured through the real station: three chops (the board's centre, then 8
// cm either side, each cutting one piece). RuntimeMesh's drain has no profiler scope and AngelScript no high-resolution clock,
// so both readings are FDateTime::UtcNow wall-clock (millisecond resolution) in a headless editor:
// - the bracket: three marker slices of the 12-triangle box are queued as the board issues the cut, so the last one drains
//   in the same RuntimeMesh pass right before the meat's slice (two a frame); from its resolution to the meat piece's
//   OnCutResolved is the slice plus the commit of its halves. Valid only when both fall between the same two frame polls.
// - the frame delta: the wall-clock length of the frame the slice drained in against the median of the 15 idle frames before
//   the chop. The lanes pin 60 fps, so a cut cheaper than the frame's slack does not show in it.
// The numbers are logged ([DicingStation cost]); only a loose sanity bound is asserted.
class UMars_AutoTest_DicingStation_MeatCutCostIsMeasured : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(15200.0, -9000.0, -30000.0);
    private const int32 k_IdleFrames = 15;
    private const int32 k_MarkerCount = 3;
    // A cut that takes a quarter of a second is a defect whatever the machine.
    private const float64 k_SanityMs = 250.0;

    private FCk_Handle_RuntimeMesh _Marker;
    private FCk_Handle _MarkerOwner;
    private TArray<float32> _Laterals;
    private int32 _Cut = 0;

    // Wall-clock seconds of every poll of the current measurement, and of the events inside it.
    private TArray<float64> _Polls;
    private float64 _IdleMedianMs = 0.0;
    private bool _ArmMarkers = false;
    private int32 _MarkersResolved = 0;
    private float64 _LastMarkerSeconds = -1.0;
    private float64 _CommitSeconds = -1.0;
    private int32 _SourceTriangles = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars::Food_MeatSlab_Mars);

        auto MarkerEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Marker = utils_runtime_mesh::Add(MarkerEntity, FCk_RuntimeMesh_Spec(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"))));
        _MarkerOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);

        _Laterals.Add(0.0f);
        _Laterals.Add(8.0f);
        _Laterals.Add(-8.0f);

        Add_Steps_IntakeTheJoint();
        Add_Step_WaitUntil("the board holds one shown joint and the marker mesh is Ready", n"Check_Ready", 0, 10.0f);
        for (int32 Cut = 0; Cut < _Laterals.Num(); ++Cut)
        {
            Add_Step("move the hand to the cut", n"Step_MoveHand");
            Add_Step_WaitUntil("the hand is there and the cleaver is up", n"Check_HandReady", 0, 2.0f);
            Add_Step("sample idle frames", n"Step_BeginIdle");
            Add_Step_WaitUntil("the idle frames are sampled", n"Check_IdleSampled", 0, 3.0f);
            Add_Step("chop, arming the markers", n"Step_Chop");
            Add_Step_WaitUntil("the cut committed and the frame after it was polled", n"Check_Committed", 0, 5.0f);
            Add_Step("record the cut", n"Step_Record");
        }
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && Get_AllHeldShown()
            && utils_runtime_mesh::Get_SetupState(_Marker) == ECk_RuntimeMesh_SetupState::Ready);
    }

    UFUNCTION()
    private void Step_MoveHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveHandTo(_Laterals[_Cut]);
    }

    UFUNCTION()
    private void Check_HandReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Dicing.Get_HandLateral() - _Laterals[_Cut]) < 0.01f && _Dicing.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Step_BeginIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Polls.Empty();
    }

    UFUNCTION()
    private void Check_IdleSampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Polls.Add(Get_WallSeconds());
        auto Res = OutResult;
        Res.Set(_Polls.Num() > k_IdleFrames);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<float64> IdleMs;
        for (int32 Index = 1; Index < _Polls.Num(); ++Index)
        { IdleMs.Add((_Polls[Index] - _Polls[Index - 1]) * 1000.0); }

        _IdleMedianMs = Get_Median(IdleMs);

        _Polls.Empty();
        _MarkersResolved = 0;
        _LastMarkerSeconds = -1.0;
        _CommitSeconds = -1.0;
        _SourceTriangles = 0;
        _ArmMarkers = true;

        for (const auto& Piece : _Board.Get_Held())
        {
            auto Watched = Piece;
            Watched.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnMeasuredCutResolved"));
        }

        Chop();
    }

    protected void On_CutIssued(const FMars_FoodBoard_CutIssue& InIssue) override
    {
        if (_ArmMarkers == false)
        { return; }

        _ArmMarkers = false;
        for (int32 Index = 0; Index < k_MarkerCount; ++Index)
        {
            auto Slice = FCk_Request_RuntimeMesh_Slice();
            Slice.Set_OperationID(FGuid::NewGuid());
            Slice.Set_ResultOwner(_MarkerOwner);
            auto Plane = FCk_RuntimeMesh_PlaneLocal();
            Plane.Set_PositionCm(FVector(5.0, 5.0, 5.0));
            Plane.Set_Normal(FVector::ForwardVector);
            Plane.Set_Tangent(FVector::UpVector);
            Slice.Set_Plane(Plane);
            utils_runtime_mesh::Request_Slice(_Marker, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnMarkerResolved"));
        }
    }

    // One poll past the commit closes the frame it happened in. A chop that issued nothing settles at once.
    UFUNCTION()
    private void Check_Committed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Polls.Add(Get_WallSeconds());
        const auto Knocked = _Issues.Num() > _Cut && _Issues[_Cut].Issued == 0;
        auto Res = OutResult;
        Res.Set(Knocked || (_CommitSeconds > 0.0 && _Polls[_Polls.Num() - 1] > _CommitSeconds));
    }

    UFUNCTION()
    private void Step_Record(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_CommitSeconds > 0.0, f"cut {_Cut} at {_Laterals[_Cut]} cm committed");
        Assert_Equals_Int(_MarkersResolved, k_MarkerCount, f"cut {_Cut}: every marker resolved");
        if (_CommitSeconds <= 0.0)
        {
            ++_Cut;
            return;
        }

        // The polls around the commit bound the frame it happened in.
        auto FrameMs = -1.0;
        auto FrameStart = -1.0;
        for (int32 Index = 1; Index < _Polls.Num(); ++Index)
        {
            if (_Polls[Index - 1] <= _CommitSeconds && _CommitSeconds <= _Polls[Index])
            {
                FrameMs = (_Polls[Index] - _Polls[Index - 1]) * 1000.0;
                FrameStart = _Polls[Index - 1];
            }
        }

        const auto BracketMs = (_CommitSeconds - _LastMarkerSeconds) * 1000.0;
        const auto BracketIsOneFrame = _LastMarkerSeconds >= FrameStart && FrameStart >= 0.0;
        const FString BracketFrame = BracketIsOneFrame ? "same frame" : "NOT one frame, invalid";

        ck::Trace(f"[DicingStation cost] cut {_Cut} at {_Laterals[_Cut]} cm of a {_SourceTriangles}-triangle piece: bracket {BracketMs :.1} ms "
            + f"({BracketFrame}), drain frame {FrameMs :.1} ms vs idle median {_IdleMedianMs :.1} ms "
            + "(UtcNow wall-clock, ms resolution, headless editor)");

        Assert_True(BracketIsOneFrame, f"cut {_Cut}: the last marker and the commit fell in one frame (the bracket is one RuntimeMesh pass)");
        Assert_True(BracketMs >= 0.0 && BracketMs < k_SanityMs, f"cut {_Cut}: the bracket ({BracketMs :.1} ms) is under {k_SanityMs} ms");
        Assert_True(FrameMs > 0.0 && FrameMs < 4.0 * k_SanityMs, f"cut {_Cut}: the drain frame ({FrameMs :.1} ms) is bounded");

        ++_Cut;
    }

    // Insertion sort of a copy: a handful of frames.
    private float64 Get_Median(TArray<float64> InValues) const
    {
        auto Values = InValues;
        for (int32 Index = 1; Index < Values.Num(); ++Index)
        {
            const auto Value = Values[Index];
            auto Slot = Index - 1;
            while (Slot >= 0 && Values[Slot] > Value)
            {
                Values[Slot + 1] = Values[Slot];
                --Slot;
            }

            Values[Slot + 1] = Value;
        }

        return Values.Num() > 0 ? Values[Math::IntegerDivisionTrunc(Values.Num(), 2)] : 0.0;
    }

    private float64 Get_WallSeconds() const
    {
        return (FDateTime::UtcNow() - FDateTime::MinValue()).GetTotalSeconds();
    }

    UFUNCTION()
    private void OnMarkerResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        ++_MarkersResolved;
        _LastMarkerSeconds = Get_WallSeconds();
    }

    UFUNCTION()
    private void OnMeasuredCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut || _CommitSeconds > 0.0)
        { return; }

        _CommitSeconds = Get_WallSeconds();
        _SourceTriangles = utils_runtime_mesh::Get_Metrics(InSource.Get_Geometry()).Get_TriangleCount();
    }
}
