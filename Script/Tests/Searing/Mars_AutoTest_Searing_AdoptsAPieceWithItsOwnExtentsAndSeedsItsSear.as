// A box cut through its middle gives two halves whose origin is still the box's, so each half's middle is off its origin.
// The positive half, its +X face given 0.5 sear first, is released with its middle over the cold pan's centre: the kernel
// reads its middle and half extents from its metrics (CentreLocal off zero, half the box along the cut), it comes to rest
// with its middle (not its origin) over the centre on its -Z face, found on the pan from its middle, and its sear arrives as
// its cook state was (+X 0.5, the rest raw).
class UMars_AutoTest_Searing_AdoptsAPieceWithItsOwnExtentsAndSeedsItsSear : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private const float32 k_SeededSear = 0.5f;
    // How far a settling half may stray from where it was released.
    private const float64 k_SettleTolerance = 2.0;

    private FVector _BoxHalfExtents;
    private FCk_Handle_FoodPiece _Half;
    private FMars_CookingFeed_PieceId _HalfId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("cut the box through its middle", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved", n"Check_Cut", 0, 3.0f);
        Add_Step("give the positive half's +X face 0.5 sear", n"Step_SeedSear");
        Add_Step_WaitFrames("the cook state drains", 2);
        Add_Step("release the half with its middle over the pan's centre", n"Step_ReleaseHalf");
        Add_Step_WaitUntil("the half landed on the pan", n"Check_HalfOnPan", 0, 3.0f);
        Add_Step_WaitSeconds("the half settles", 0.3f);
        Add_Step("its own extents, its middle over the centre, its sear as it came", n"Step_AssertAdopted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Box = Take_Piece();
        _BoxHalfExtents = Get_HalfExtents(Box);
        Cut(Box, Get_BoundsCenter(Box), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_Cut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_CutCount(EMars_FoodPiece_CutOutcome::Cut) >= 1);
    }

    UFUNCTION()
    private void Step_SeedSear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Half = Get_FirstCut(EMars_FoodPiece_CutOutcome::Cut).Positive;
        Assert_True(_Half.Get_Status() == EMars_FoodPiece_Status::Ready, "the half is Ready");

        auto CookState = _Half.Get_CookState();
        CookState.FaceSear[int32(EMars_Searing_Face::PosX)] = k_SeededSear;
        _Half.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
    }

    UFUNCTION()
    private void Step_ReleaseHalf(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Half.Get_CookState().FaceSear[int32(EMars_Searing_Face::PosX)], k_SeededSear, 0.0001,
            "the half carries its +X sear before it is released");

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
        Assert_True(State.Piece == _Half, "the pan holds the half itself");
        Assert_True((State.CentreLocal - Get_BoundsCenter(_Half)).Size() < 0.01,
            f"CentreLocal {State.CentreLocal} is the middle of the half's bounds {Get_BoundsCenter(_Half)}");
        Assert_True(State.CentreLocal.Size() > 0.5, f"the half's middle is off its origin (CentreLocal {State.CentreLocal})");
        Assert_Equals_Float(State.HalfExtents.X, _BoxHalfExtents.X * 0.5, 0.05, "the half is half the box along the cut");
        Assert_Equals_Float(State.HalfExtents.Y, _BoxHalfExtents.Y, 0.05, "the half is the box's width");
        Assert_Equals_Float(State.HalfExtents.Z, _BoxHalfExtents.Z, 0.05, "the half is the box's height");

        const auto Middle = _Searing.Get_PiecePanLocal(_HalfId);
        const auto Origin = _Searing.Get_PanBaseWorld().InverseTransformPosition(Get_World(_Half).GetLocation());
        ck::Trace(f"[Searing] adopted half: middle at pan-local {Middle}, origin at {Origin}, half extents {State.HalfExtents}");
        Assert_True(Middle.Size2D() < k_SettleTolerance, f"its middle came to rest over the pan's centre (pan-local {Middle})");
        Assert_Equals_Float(Middle.Z, utils_searing::k_PanSurfaceZ + State.HalfExtents.Z, 1.0,
            "its middle rests its half height above the cooking surface");
        Assert_True((Origin - Middle).Size() > 0.5, "its origin is not its middle");
        Assert_True(Get_IsOnPan(_HalfId), "the pan finds it on the pan from its middle");

        const auto Down = _Searing.Get_DownFace(_HalfId);
        Assert_True(Down == EMars_Searing_Face::NegZ, f"it lies on its -Z face (got {Down :n})");

        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            const auto Expected = Face == EMars_Searing_Face::PosX ? float64(k_SeededSear) : 0.0;
            Assert_Equals_Float(_Searing.Get_FaceSear(_HalfId, Face), Expected, 0.0001,
                f"face {utils_searing::Get_FaceName(Face)} arrived with the half's sear");
        }

        Assert_True(_Searing.Get_PieceStatus(_HalfId) == EMars_Searing_PieceStatus::Cooking, "a half-seared face leaves it cooking");
        Assert_Equals_Int(_Seared.Num() + _ProgressSignals, 0, "nothing sears on the cold pan");
    }
}

class AMars_AutoTest_Searing_AdoptsAPieceWithItsOwnExtentsAndSeedsItsSear_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AdoptsAPieceWithItsOwnExtentsAndSeedsItsSear;
}
