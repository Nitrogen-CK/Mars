// A thin slice is judged by how far it fell, not by its own thickness. The rig's box is cut 1 cm under its top; the 1 cm
// slice is released flat over the hot pan's centre and left to rest (its depth under the cooking surface and its contact
// edges are logged: the pan body's surface against k_PanSurfaceZ, and whether a resting slice on a still pan flickers).
// Then it is held with its middle 0.8 cm under the cooking surface for 3 s (more than its own half height of 0.5 cm, far
// less than Loss.FallThroughCm): it is never lost, it is on the pan at the end, and its down face keeps searing.
class UMars_AutoTest_Searing_AThinSliceRestingInThePanIsNotLost : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 20.0f;

    private const float64 k_SliceThickness = 1.0;
    private const float64 k_SunkDepth = 0.8;
    private const float32 k_HoldSeconds = 3.0f;
    // Slow enough that the hold's sear is measurable (the rig's 0.2 s would sear the face before the hold).
    private const float32 k_SecondsPerFace = 10.0f;

    private FCk_Handle_FoodPiece _Slice;
    private FMars_CookingFeed_PieceId _SliceId;
    private int32 _ContactsAtRest = 0;
    private float32 _HoldStart = -1.0f;
    private float32 _SearAtHoldStart = 0.0f;
    private bool _LostDuringHold = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = k_SecondsPerFace;
        BuildStation(InHandle, Spec);
        Build_Pieces(1);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("cut the box 1 cm under its top", n"Step_CutSlice");
        Add_Step_WaitUntil("the cut resolved", n"Check_Cut", 0, 3.0f);
        Add_Step("heat the pan and release the slice flat over its centre", n"Step_ReleaseSlice");
        Add_Step_WaitUntil("the slice landed on the pan", n"Check_SliceOnPan", 0, 3.0f);
        Add_Step("note the contact edges so far", n"Step_NoteLanding");
        Add_Step_WaitSeconds("the slice rests on the still pan", 1.5f);
        Add_Step("log where a resting slice sits and whether it flickered", n"Step_LogRest");
        Add_Step_WaitUntil("hold the slice 0.8 cm under the surface for 3 s", n"Check_HoldSunk", 0, k_HoldSeconds + 2.0f);
        Add_Step_WaitFrames("the last hold frame is judged", 2);
        Add_Step("never lost, on the pan, and its down face kept searing", n"Step_AssertKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_CutSlice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Box = Take_Piece();
        const auto Metrics = Get_Metrics(Box);
        const auto Centre = Get_BoundsCenter(Box);
        Cut(Box, FVector(Centre.X, Centre.Y, Metrics.Get_BoundsMaxCm().Z - k_SliceThickness), FVector::UpVector);
    }

    UFUNCTION()
    private void Check_Cut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut) >= 1);
    }

    UFUNCTION()
    private void Step_ReleaseSlice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Slice = Get_FirstCut(EMars_FoodPiece_CutOutcome::Cut).Positive;
        const auto HalfExtents = Get_HalfExtents(_Slice);
        Assert_Equals_Float(HalfExtents.Z, k_SliceThickness * 0.5, 0.05, "the slice is 1 cm thick");

        Heat();
        _SliceId = FMars_CookingFeed_PieceId(k_Generation, _NextIndex);
        _NextIndex += 1;
        Release_ThePiece(_SliceId, _Slice, FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + HalfExtents.Z + k_DropClearance));
    }

    UFUNCTION()
    private void Check_SliceOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOnPan(_SliceId));
    }

    UFUNCTION()
    private void Step_NoteLanding(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _ContactsAtRest = _Contacts.Num();
    }

    UFUNCTION()
    private void Step_LogRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Local = Get_SliceLocal();
        const auto Edges = _Contacts.Num() - _ContactsAtRest;
        Log(f"[Searing test] a resting 1 cm slice: middle {Local.Z - utils_searing::k_PanSurfaceZ :.3} cm above k_PanSurfaceZ "
            + f"(its half height {Get_HalfExtents(_Slice).Z :.3}), {Edges} contact edge(s) in 1.5 s on the still pan");
        Assert_True(_LostIds.Num() == 0, "the resting slice was not lost");
    }

    UFUNCTION()
    private void Check_HoldSunk(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Searing.Get_HasPiece(_SliceId) == false || _Searing.Get_PieceState(_SliceId).Status == EMars_Searing_PieceStatus::Lost)
        {
            _LostDuringHold = true;
            Res.Set(true);
            return;
        }

        if (_HoldStart < 0.0f)
        {
            _HoldStart = Get_Now();
            _SearAtHoldStart = Get_DownSear();
        }

        Teleport_Piece(_SliceId, FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ - k_SunkDepth), FRotator::ZeroRotator);
        Res.Set(Get_Now() - _HoldStart >= k_HoldSeconds);
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_LostDuringHold, "the slice held 0.8 cm under the surface was never lost");
        Assert_True(_LostIds.Num() == 0, "no piece was lost");
        if (_LostDuringHold || _Searing.Get_HasPiece(_SliceId) == false)
        { return; }

        const auto State = _Searing.Get_PieceState(_SliceId);
        Assert_True(State.Status == EMars_Searing_PieceStatus::Cooking, f"the slice is still Cooking (got [{State.Status :n}])");
        Assert_True(State.Contact == EMars_Searing_Contact::OnPan, f"the slice is on the pan (got [{State.Contact :n}])");

        const auto Seared = Get_DownSear() - _SearAtHoldStart;
        Log(f"[Searing test] the held slice's down face seared {Seared :.3} in {k_HoldSeconds} s ({k_HoldSeconds / k_SecondsPerFace :.3} if on the pan throughout)");
        Assert_True(Seared >= 0.5f * k_HoldSeconds / k_SecondsPerFace, f"the down face kept searing while held ({Seared :.3})");
    }

    // The slice's middle in the pan base's frame.
    private FVector Get_SliceLocal() const
    {
        const auto SliceWorld = Get_World(_Slice);
        const auto State = _Searing.Get_PieceState(_SliceId);
        return _Searing.Get_PanBaseWorld().InverseTransformPosition(SliceWorld.TransformPosition(State.CentreLocal));
    }

    private float32 Get_DownSear() const
    {
        return _Searing.Get_PieceState(_SliceId).FaceSear[int32(EMars_Searing_Face::NegZ)];
    }
}

class AMars_AutoTest_Searing_AThinSliceRestingInThePanIsNotLost_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AThinSliceRestingInThePanIsNotLost;
}
