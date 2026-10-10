// A piece taken off a platter keeps the body it dropped with, Kinematic. Such a joint J and a second Kinematic-bodied box U
// are placed on a yawed board: neither is refused. J is cut through its middle: its halves are new entities born without a
// body and take J's place beside U, and J goes. U keeps its Kinematic body on the board.
class UMars_AutoTest_FoodBoard_KinematicBodiedJointIsPlacedAndCut : UMars_AutoTestRig_FoodBoard
{
    private const FVector k_Origin = FVector(7200.0, 3000.0, -42000.0);

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodPiece _J;
    private FCk_Handle_FoodPiece _U;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), k_Origin), Make_Tuners());
        _J = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.0)), 0.8);
        _U = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(40.0, 0.0, 0.0)), 0.4);

        Add_Step_WaitUntil("both boxes are Ready", n"Check_Ready");
        Add_Step("give both a body, as a platter's drop does", n"Step_GiveBodies");
        Add_Step_WaitUntil("both bodies read Kinematic", n"Check_Kinematic");
        Add_Step("place both on the board", n"Step_Place");
        Add_Step_WaitUntil("both are placed", n"Check_Placed");
        Add_Step("neither was refused; cut J through its middle", n"Step_AssertPlacedAndCut");
        Add_Step_WaitUntil("J's cut committed", n"Check_Cut");
        Add_Step("the halves are new, bodiless entities beside U, which kept its body", n"Step_AssertHalves");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_J) && Get_HasReadied(_U));
    }

    UFUNCTION()
    private void Step_GiveBodies(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_foodpiece::Add_Body(_J);
        utils_foodpiece::Add_Body(_U);
    }

    // The SetMotionType handler drops a request that reaches a body not added yet: ask until the mirror reads it.
    UFUNCTION()
    private void Check_Kinematic(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Ask_Kinematic(_J) && Ask_Kinematic(_U));
    }

    private bool Ask_Kinematic(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        auto Body = Entity.As_JoltBody();
        if (utils_jolt_body::Get_IsBodyAdded(Body) == false)
        { return false; }

        if (utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic)
        { return true; }

        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        return false;
    }

    UFUNCTION()
    private void Step_Place(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Place(_Board, _J);
        Place(_Board, _U);
    }

    UFUNCTION()
    private void Check_Placed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) + Get_Refusals(_Board).Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertPlacedAndCut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_Refusals(_Board).Num(), 0, "a Kinematic-bodied piece is not refused Loose");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the board holds both");

        Chop(_Board, Make_WorldPlane(Get_WorldBoundsCenter(_J), Get_BoardWorld(_Board).TransformVectorNoScale(FVector::ForwardVector)));
    }

    UFUNCTION()
    private void Check_Cut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceCuts(_Board).Num() >= 1 || (Get_Issues(_Board).Num() >= 1 && Get_Issues(_Board)[0].Issued == 0));
    }

    UFUNCTION()
    private void Step_AssertHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Cuts = Get_PieceCuts(_Board);
        Assert_Equals_Int(Cuts.Num(), 1, "J was cut once");
        if (Cuts.Num() != 1)
        { return; }

        Assert_True(Cuts[0].Source == _J, "the cut was J's");
        TArray<FCk_Handle_FoodPiece> Halves;
        Halves.Add(Cuts[0].Positive);
        Halves.Add(Cuts[0].Negative);
        for (const auto& Half : Halves)
        {
            FCk_Handle Entity = Half;
            Assert_True(Half != _J, f"[{Half.ToString()}] is a new entity, not J");
            Assert_False(Entity.Is_JoltBody(), f"[{Half.ToString()}] is born without a body");
        }

        Assert_True(Get_IsEnding(_J), "J is going");
        Assert_Equals_Int(_Board.Get_HeldCount(), 3, "the board holds the two halves and U");

        FCk_Handle UEntity = _U;
        Assert_False(Get_IsEnding(_U), "U is untouched by J's cut");
        Assert_True(UEntity.Is_JoltBody() && utils_jolt_body::Get_MotionType(UEntity.As_JoltBody()) == ECk_MotionType::Kinematic,
            "U keeps its Kinematic body on the board");
    }

    private bool Get_IsEnding(FCk_Handle_FoodPiece InPiece) const
    {
        return ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }
}
