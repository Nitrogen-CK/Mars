// A real cut piece sears like the old cube. The meat slab (MeatSlab_Mars_SM, as its food builds it) is cut once across its
// long X axis at its centroid, as the cutting bench's cleaver parts it, and its positive half (about 18.3 x 20.0 x 12.2 cm,
// its middle off its origin) is released over the hot pan's centre. The pan adopts it with its own extents (half the
// slab's along the cut, the slab's across it) and its middle; it lands on its -Z face. Teleported onto the pan with each
// face down in turn (utils_searing::Make_FaceDownRotation, about its middle), that face is the one on the pan
// (Get_DownFace agrees), its middle rests its own half extent along that face's axis above the cooking surface, the
// footprint the pan pools under it spans the two half extents across that face (Get_PieceFootprintHalf), and it sears
// through; each teleport after the first counts a flip, and the sixth seared face makes the half Ready once, on the pan,
// never lost, every face seared through in the cook state the pan hands back.
class UMars_AutoTest_Searing_ACutSlabHalfSearsEverySideAndIsReady : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 40.0f;

    private FCk_Handle_FoodPiece _Slab;
    private FVector _SlabHalfExtents;
    private FCk_Handle_FoodPiece _Half;
    private FMars_CookingFeed_PieceId _HalfId;
    private TArray<EMars_Searing_Face> _Order;
    private int32 _FaceIndex = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = 0.15f;
        BuildStation(InHandle, Spec);

        auto Slab = mars::Food_MeatSlab_Mars;
        _Slab = Build_Piece(Slab.Data.Mesh, FTransform(FRotator::ZeroRotator, k_Origin + k_ParkLocal), Make_FoodSpec(Slab.Data.MassKg, Slab));
        _Pieces.Add(_Slab);

        _Order.Add(EMars_Searing_Face::NegZ);
        _Order.Add(EMars_Searing_Face::PosZ);
        _Order.Add(EMars_Searing_Face::PosX);
        _Order.Add(EMars_Searing_Face::NegX);
        _Order.Add(EMars_Searing_Face::PosY);
        _Order.Add(EMars_Searing_Face::NegY);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", k_SlowPolls, 0);
        Add_Step_WaitUntil("the slab is Ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("cut the slab across its long axis at its centroid", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved", n"Check_Cut", k_SlowPolls, 0);
        Add_Step("release the positive half with its middle over the pan's centre", n"Step_ReleaseHalf");
        Add_Step_WaitUntil("the half landed on the pan", n"Check_HalfOnPan", k_SlowPolls, 0);
        Add_Step("the pan adopted the half with its own extents, on its -Z face", n"Step_AssertAdopted");
        for (int32 Index = 0; Index < _Order.Num(); ++Index)
        {
            Add_Step(f"teleport face {utils_searing::Get_FaceName(_Order[Index])} down onto the pan", n"Step_TeleportNextFace");
            Add_Step_WaitFrames("the teleport is applied and written back", 4);
            Add_Step_WaitUntil("the half is on the pan", n"Check_HalfOnPan", k_SlowPolls, 0);
            Add_Step("the teleported face is the one on the pan, and the footprint spans it", n"Step_AssertDownFace");
            Add_Step_WaitUntil("that face seared", n"Check_CurrentFaceSeared", k_SlowPolls, 0);
        }

        Add_Step_WaitUntil("the half is ready", n"Check_Ready1", 0, 0);
        Add_Step("six faces seared, flips counted, the half is ready once and still on the pan", n"Step_AssertReady");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SlabHalfExtents = Get_HalfExtents(_Slab);
        Cut(_Slab, Get_Metrics(_Slab).Get_CentroidCm(), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_Cut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() > 0);
    }

    UFUNCTION()
    private void Step_ReleaseHalf(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _Cuts[0];
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        {
            FinishFailure(f"the slab was not cut (got {Result.Outcome :n})");
            return;
        }

        _Half = Result.Positive;
        Assert_True(_Half.Get_Status() == EMars_FoodPiece_Status::Ready, "the half is Ready");
        Assert_False(_Half.Get_IsWhole(), "the half is a cut piece");

        _HalfId = FMars_CookingFeed_PieceId(k_Generation, _NextIndex);
        _NextIndex += 1;
        Release_ThePiece(_HalfId, _Half, FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + Get_HalfExtents(_Half).Z + k_DropClearance));
    }

    UFUNCTION()
    private void Check_HalfOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_AddedIds.Num() > 0 && Get_IsOnPan(_HalfId));
    }

    UFUNCTION()
    private void Step_AssertAdopted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AdmissionCount(EMars_CookingFeed_Admission::Accepted), 1, "the half was accepted");

        const auto State = _Searing.Get_PieceState(_HalfId);
        ck::Trace(f"[Searing] slab half extents {State.HalfExtents} (slab {_SlabHalfExtents}), CentreLocal {State.CentreLocal}");
        Assert_True(State.Piece == _Half, "the pan holds the half itself");
        Assert_True((State.CentreLocal - Get_BoundsCenter(_Half)).Size() < 0.01, "the pan reads the half's middle from its bounds");
        Assert_True(State.CentreLocal.Size2D() > 1.0, f"the half's middle is off its origin (CentreLocal {State.CentreLocal})");
        Assert_Equals_Float(State.HalfExtents.X, _SlabHalfExtents.X * 0.5, 0.5, "the half is about half the slab along the cut");
        Assert_Equals_Float(State.HalfExtents.Y, _SlabHalfExtents.Y, 0.5, "the half is about the slab's width");
        Assert_Equals_Float(State.HalfExtents.Z, _SlabHalfExtents.Z, 0.5, "the half is about the slab's height");

        const auto Down = _Searing.Get_DownFace(_HalfId);
        Assert_True(Down == EMars_Searing_Face::NegZ, f"it lies on its -Z face as released (got {Down :n})");
        Assert_Equals_Int(_Lost.Num(), 0, "nothing was lost");
    }

    // The half's own half extent along InFace's axis.
    private float64 Get_HalfExtentAlong(EMars_Searing_Face InFace) const
    {
        const auto HalfExtents = _Searing.Get_PieceHalfExtents(_HalfId);
        const auto Normal = utils_searing::Get_FaceNormal(InFace);
        return Math::Abs(Normal.X) * HalfExtents.X + Math::Abs(Normal.Y) * HalfExtents.Y + Math::Abs(Normal.Z) * HalfExtents.Z;
    }

    UFUNCTION()
    private void Step_TeleportNextFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FaceIndex += 1;
        const auto Face = _Order[_FaceIndex];

        Assert_True(utils_jolt_body::Get_IsBodyAdded(_Searing.Get_PieceBody(_HalfId)), "the half's body is in the simulation");

        // Its own half extent along the face's axis, plus a centimetre's drop.
        Teleport_Piece(_HalfId, FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + Get_HalfExtentAlong(Face) + 1.0),
            utils_searing::Make_FaceDownRotation(Face));
    }

    UFUNCTION()
    private void Step_AssertDownFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Expected = _Order[_FaceIndex];
        const auto Down = _Searing.Get_DownFace(_HalfId);
        Assert_True(Down == Expected, f"the half lands {Expected :n} on the pan (got {Down :n})");

        const auto HalfExtents = _Searing.Get_PieceHalfExtents(_HalfId);
        const auto Along = Get_HalfExtentAlong(Expected);
        const auto Across = (HalfExtents.X + HalfExtents.Y + HalfExtents.Z - Along) * 0.5;
        Assert_Equals_Float(_Searing.Get_PieceFootprintHalf(_HalfId), Across, 0.0001,
            f"the footprint on {Expected :n} spans the two half extents across it");

        const auto Middle = _Searing.Get_PiecePanLocal(_HalfId);
        Assert_Equals_Float(Middle.Z, utils_searing::k_PanSurfaceZ + Along, 1.5,
            f"its middle rests its own half extent along {Expected :n} above the cooking surface (pan-local {Middle})");
    }

    UFUNCTION()
    private void Check_CurrentFaceSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_FaceSear(_HalfId, _Order[_FaceIndex]) >= 1.0f || _Lost.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertReady(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Lost.Num(), 0, "the half was never lost");
        Assert_Equals_Int(_ReadyIds.Num(), 1, "OnPieceReady fired once");
        if (_ReadyIds.Num() > 0)
        { Assert_True(_ReadyIds[0].Get_IsSame(_HalfId), "OnPieceReady names the half"); }

        Assert_True(_Searing.Get_PieceStatus(_HalfId) == EMars_Searing_PieceStatus::Ready, "the half is Ready");
        Assert_True(Get_IsOnPan(_HalfId), "the ready half stays on the pan");
        Assert_Equals_Int(_Searing.Get_SearedFaceCount(_HalfId), 6, "six faces seared");
        Assert_Equals_Int(_Seared.Num(), 6, "OnFaceSeared fired once per face");

        const auto Tally = _Searing.Get_Tally();
        ck::Trace(f"[Searing] cut slab half, each face down: flips {Tally.Flips}, {Tally.Seconds :.2} s hot");
        Assert_True(Tally.Flips >= 5, f"each teleport onto another face counted a flip (got {Tally.Flips}, want >= 5)");

        const auto CookState = _Searing.Get_PieceCookState(_HalfId);
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            Assert_Equals_Float(CookState.Sear[Index], 1.0, 0.0001,
                f"face {utils_searing::Get_FaceName(EMars_Searing_Face(Index))} is seared through in the cook state the pan hands back");
        }
    }
}

class AMars_AutoTest_Searing_ACutSlabHalfSearsEverySideAndIsReady_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 40.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_ACutSlabHalfSearsEverySideAndIsReady;
}
