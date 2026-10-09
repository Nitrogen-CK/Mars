// The first piece on the hot pan is made Ready by teleporting each face down in turn (as TeleportingEachFaceDown... does);
// a second, added beside it, only cooks. A TakeOut capped at zero takes nothing. An unnamed, uncapped TakeOut hands back
// exactly the Ready piece: OnPieceTakenOut names it, it leaves the pan's books (the cooking one stays), its body reads
// Kinematic, its own cook state now carries six seared faces (Penetration 1, Shape 1), it lives on, and the summary counts
// one taken out.
class UMars_AutoTest_Searing_TakeOutHandsReadyPiecesBackWithTheirCookState : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 30.0f;

    // Pan-local, on the flat base clear of the ready piece at the centre.
    private const FVector k_SecondLocal = FVector(-15.0, 0.0, 8.0);

    private TArray<EMars_Searing_Face> _Order;
    private int32 _FaceIndex = -1;
    private FMars_CookingFeed_PieceId _SecondId;
    private FCk_Handle_FoodPiece _ReadyPiece;
    private FCk_Handle_JoltBody _ReadyBody;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = 0.15f;
        BuildStation(InHandle, Spec);
        Build_Pieces(2);

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
            Add_Step_WaitUntil("that face seared", n"Check_CurrentFaceSeared", 0, 2.0f);
        }

        Add_Step_WaitUntil("the piece is ready", n"Check_Ready1", 0, 0.5f);
        Add_Step("add a second piece beside the ready one", n"Step_AddSecond");
        Add_Step_WaitUntil("the second piece landed on the pan", n"Check_SecondOnPan", 0, 3.0f);
        Add_Step("one Ready, one cooking; take out at most none", n"Step_TakeOutNone");
        Add_Step_WaitFrames("the capped take-out drains", 3);
        Add_Step("nothing left the pan; take out every Ready piece", n"Step_AssertNoneThenTakeOut");
        Add_Step_WaitUntil("the take-out was answered", n"Check_TakenOut1", 0, 1.0f);
        Add_Step_WaitUntil("the taken piece's body reads Kinematic", n"Check_TakenKinematic", 0, 1.0f);
        Add_Step_WaitFrames("the cook state drains", 2);
        Add_Step("the Ready piece came back with its cook state", n"Step_AssertTakenOut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TeleportNextFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FaceIndex += 1;
        const auto Reach = _Searing.Get_PieceHalfExtents(Get_FirstId()).GetMax();
        Teleport_Piece(Get_FirstId(), FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + Reach + 1.0),
            utils_searing::Make_FaceDownRotation(_Order[_FaceIndex]));
    }

    UFUNCTION()
    private void Check_CurrentFaceSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_FaceSear(Get_FirstId(), _Order[_FaceIndex]) >= 1.0f);
    }

    UFUNCTION()
    private void Step_AddSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SecondId = AddPieceAt(k_SecondLocal);
    }

    UFUNCTION()
    private void Check_SecondOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() == 2 && Get_IsOnPan(_SecondId));
    }

    UFUNCTION()
    private void Step_TakeOutNone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_PieceStatus(Get_FirstId()) == EMars_Searing_PieceStatus::Ready, "the first piece is Ready");
        Assert_True(_Searing.Get_PieceStatus(_SecondId) == EMars_Searing_PieceStatus::Cooking, "the second piece is cooking");
        Assert_Equals_Int(_Searing.Get_TakeableCount(), 1, "one piece is takeable");

        _ReadyPiece = _Searing.Get_PieceHandle(Get_FirstId());
        _ReadyBody = _Searing.Get_PieceBody(Get_FirstId());
        _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece>(), TOptional<int32>(0)));
    }

    UFUNCTION()
    private void Step_AssertNoneThenTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TakenOut.Num(), 0, "a take-out capped at zero hands nothing back");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 2, "both pieces are still on the pan");
        Assert_Equals_Int(_Searing.Get_Summary().TakenOut, 0, "the summary has taken nothing out");

        _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut());
    }

    UFUNCTION()
    private void Check_TakenOut1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() >= 1);
    }

    UFUNCTION()
    private void Check_TakenKinematic(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_MotionType(_ReadyBody) == ECk_MotionType::Kinematic);
    }

    UFUNCTION()
    private void Step_AssertTakenOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TakenOut.Num(), 1, "OnPieceTakenOut fired once");
        if (_TakenOut.Num() > 0)
        {
            Assert_True(_TakenOutIds[0].Get_IsSame(Get_FirstId()), "OnPieceTakenOut names the Ready piece's Id");
            Assert_True(_TakenOut[0] == _ReadyPiece, "OnPieceTakenOut hands back the Ready piece");
        }

        Assert_False(_Searing.Get_HasPiece(Get_FirstId()), "the taken piece left the pan's books");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "Get_PieceIds lists only the cooking piece");
        Assert_True(_Searing.Get_HasPiece(_SecondId), "the cooking piece stayed");
        Assert_True(ck::IsValid(_ReadyPiece), "the taken piece lives on");
        Assert_True(utils_jolt_body::Get_MotionType(_ReadyBody) == ECk_MotionType::Kinematic, "its body is Kinematic");

        const auto CookState = _ReadyPiece.Get_CookState();
        Assert_Equals_Int(CookState.FaceSear.Num(), utils_searing::k_FaceCount, "six face sears");
        for (int32 Index = 0; Index < CookState.FaceSear.Num(); ++Index)
        {
            Assert_Equals_Float(CookState.FaceSear[Index], 1.0, 0.0001,
                f"face {utils_searing::Get_FaceName(EMars_Searing_Face(Index))} is seared in its cook state");
        }

        Assert_Equals_Float(CookState.Penetration, 1.0, 0.0001, "the crust's penetration is full");
        Assert_Equals_Float(CookState.Shape, 1.0, 0.0001, "the silhouette is cooked");

        const auto Summary = _Searing.Get_Summary();
        Assert_Equals_Int(Summary.TakenOut, 1, "the summary counts one taken out");
        Assert_Equals_Int(Summary.Ready, 0, "no Ready piece is left");
        Assert_Equals_Int(Summary.Cooking, 1, "one piece cooks");
        Assert_Equals_Int(Summary.Admitted, 2, "two admitted in all");
        Assert_Equals_Int(_Searing.Get_TakeableCount(), 0, "nothing is takeable");
    }
}

class AMars_AutoTest_Searing_TakeOutHandsReadyPiecesBackWithTheirCookState_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_TakeOutHandsReadyPiecesBackWithTheirCookState;
}
