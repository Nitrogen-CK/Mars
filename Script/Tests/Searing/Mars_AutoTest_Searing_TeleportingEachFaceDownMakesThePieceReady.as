// Teleporting a piece onto the hot pan with each face down in turn (utils_searing::Make_FaceDownRotation) lands that face
// on the pan (Get_DownFace agrees) and sears it; the sixth seared face makes that piece Ready once (OnPieceReady), not the
// station: the ready piece stays on the pan, inert (no sizzle, the tally's seconds stop), and a second piece added beside
// it still sears its down face. Each teleport after the first (NegZ, the resting face at admission) changes the resting
// face, so it counts a flip.
class UMars_AutoTest_Searing_TeleportingEachFaceDownMakesThePieceReady : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 30.0f;

    // Pan-local, on the flat base clear of the ready piece at the centre.
    private const FVector k_SecondLocal = FVector(-15.0, 0.0, 8.0);
    // How long the ready piece alone is watched for any more cooking.
    private const float32 k_InertSeconds = 0.3f;

    private TArray<EMars_Searing_Face> _Order;
    private int32 _FaceIndex = -1;
    private float32 _TallySecondsAtReady = 0.0f;
    private FMars_CookingFeed_PieceId _SecondId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = 0.15f;
        BuildStation(InHandle, Spec);

        _Order.Add(EMars_Searing_Face::NegZ);
        _Order.Add(EMars_Searing_Face::PosZ);
        _Order.Add(EMars_Searing_Face::PosX);
        _Order.Add(EMars_Searing_Face::NegX);
        _Order.Add(EMars_Searing_Face::PosY);
        _Order.Add(EMars_Searing_Face::NegY);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Steps_AddPieceAndLand();
        for (int32 Index = 0; Index < _Order.Num(); ++Index)
        {
            Add_Step(f"teleport face {utils_searing::Get_FaceName(_Order[Index])} down onto the pan", n"Step_TeleportNextFace");
            Add_Step_WaitFrames("the teleport is applied and written back", 4);
            Add_Step_WaitUntil("the piece is on the pan", n"Check_FirstOnPan", 0, 2.0f);
            Add_Step("the teleported face is the one on the pan", n"Step_AssertDownFace");
            Add_Step_WaitUntil("that face seared", n"Check_CurrentFaceSeared", 0, 2.0f);
        }

        Add_Step_WaitUntil("the piece is ready", n"Check_Ready1", 0, 0.5f);
        Add_Step("six faces seared and the piece is ready once", n"Step_AssertReady");
        Add_Step_WaitSeconds("the ready piece sits on the hot pan", k_InertSeconds);
        Add_Step("the ready piece is inert; add a second piece", n"Step_AssertInertAndAddSecond");
        Add_Step_WaitUntil("the second piece landed on the pan", n"Check_SecondOnPan", 0, 3.0f);
        Add_Step_WaitUntil("the second piece's down face seared", n"Check_SecondDownFaceSeared", 0, 2.0f);
        Add_Step("the second piece cooked beside the ready one", n"Step_AssertSecondCooked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TeleportNextFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FaceIndex += 1;
        const auto Face = _Order[_FaceIndex];

        // On the pan implies the body exists in the simulation; a teleport before that does nothing.
        auto Body = _Searing.Get_PieceBody(Get_FirstId());
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the piece's body is in the simulation");

        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto Location = PanBaseWorld.TransformPosition(FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + _Spec.Steak.HalfSize + 1.0));
        const auto Rotation = (FQuat(PanBaseWorld.Rotator()) * FQuat(utils_searing::Make_FaceDownRotation(Face))).Rotator();
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Location, Rotation));
    }

    UFUNCTION()
    private void Step_AssertDownFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Expected = _Order[_FaceIndex];
        const auto Down = _Searing.Get_DownFace(Get_FirstId());
        Assert_True(Down == Expected,
            f"Make_FaceDownRotation({Expected :n}) = {utils_searing::Make_FaceDownRotation(Expected)} lands {Expected :n} on the pan (got {Down :n})");
    }

    UFUNCTION()
    private void Check_CurrentFaceSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_FaceSear(Get_FirstId(), _Order[_FaceIndex]) >= 1.0f);
    }

    UFUNCTION()
    private void Step_AssertReady(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceId = Get_FirstId();
        Assert_Equals_Int(_ReadyIds.Num(), 1, "OnPieceReady fired once");
        if (_ReadyIds.Num() > 0)
        { Assert_True(_ReadyIds[0].Get_IsSame(PieceId), "OnPieceReady names the piece"); }

        const auto Status = _Searing.Get_PieceStatus(PieceId);
        Assert_True(Status == EMars_Searing_PieceStatus::Ready, f"the piece is Ready (got {Status :n})");
        Assert_True(Get_IsOnPan(PieceId), "the ready piece stays on the pan");
        Assert_Equals_Int(_Searing.Get_SearedFaceCount(PieceId), 6, "six faces seared");
        Assert_Equals_Int(_Seared.Num(), 6, "OnFaceSeared fired once per face");

        const auto Summary = _Searing.Get_Summary();
        Assert_Equals_Int(Summary.Ready, 1, "the summary counts one ready");
        Assert_Equals_Int(Summary.Cooking, 0, "nothing else cooks");

        const auto Tally = _Searing.Get_Tally();
        ck::Trace(f"[Searing] teleported each face down: flips {Tally.Flips}, {Tally.Seconds :.2} s hot");
        Assert_True(Tally.Flips >= 5, f"each teleport onto another face counted a flip (got {Tally.Flips}, want >= 5)");
        _TallySecondsAtReady = Tally.Seconds;
    }

    UFUNCTION()
    private void Step_AssertInertAndAddSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Sizzles.Num() > 0 && _Sizzles.Last() == EMars_Searing_Sizzle::Quiet, "a ready piece does not sizzle");
        Assert_True(_Searing.Get_IsHot(), "the pan stays hot");
        Assert_Equals_Float(_Searing.Get_Tally().Seconds, _TallySecondsAtReady, 0.0001,
            "the tally's seconds stopped with nothing cooking");
        Assert_Equals_Int(_ReadyIds.Num(), 1, "OnPieceReady did not fire again");

        _SecondId = AddPieceAt(k_SecondLocal);
    }

    UFUNCTION()
    private void Check_SecondOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() == 2 && Get_IsOnPan(_SecondId));
    }

    UFUNCTION()
    private void Check_SecondDownFaceSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_HasPiece(_SecondId) && _Searing.Get_IsDownFaceSeared(_SecondId));
    }

    UFUNCTION()
    private void Step_AssertSecondCooked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_AddedIds.Num() == 2 && _AddedIds[1].Get_IsSame(_SecondId), "the second piece was admitted");
        Assert_True(_Searing.Get_PieceEntity(_SecondId) != _Searing.Get_PieceEntity(Get_FirstId()), "two distinct entities");
        Assert_True(_Searing.Get_PieceStatus(_SecondId) == EMars_Searing_PieceStatus::Cooking, "the second piece is cooking");
        Assert_True(_Searing.Get_PieceStatus(Get_FirstId()) == EMars_Searing_PieceStatus::Ready, "the first piece is still Ready");
        Assert_True(_Searing.Get_Tally().Seconds > _TallySecondsAtReady, "the tally's seconds run again while a piece cooks");
        Assert_Equals_Int(_ReadyIds.Num(), 1, "only the first piece is ready");

        const auto Summary = _Searing.Get_Summary();
        Assert_Equals_Int(Summary.Admitted, 2, "two pieces admitted");
        Assert_Equals_Int(Summary.Ready, 1, "one ready");
        Assert_Equals_Int(Summary.Cooking, 1, "one cooking");
    }
}

class AMars_AutoTest_Searing_TeleportingEachFaceDownMakesThePieceReady_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_TeleportingEachFaceDownMakesThePieceReady;
}
