// A cut-sized piece loaded onto a still platter drops between its walls, settles with physics and freezes into the pile:
// within 3 s OnLoaded fires once, the piece is a scene-node child of the root, its body reads Kinematic and its bounds centre
// lies inside the walls. The platter root then moves 50 cm and the piece moves with it.
class UMars_AutoTest_Platter_ADroppedPieceSettlesFreezesAndRidesTheTray : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -18000.0, -30000.0);
    private const FVector k_Move = FVector(50.0, 0.0, 0.0);

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FVector _BeforeMove;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, 30.0, 0.0), k_Origin), Make_PlatterSpec(4));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        Add_Step_WaitUntil("P is Ready", n"Check_Ready");
        Add_Step("load P", n"Step_Load");
        Add_Step_WaitUntil("P froze into the pile within 3 s", n"Check_Loaded", 0, 3.0f);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("P is held, Kinematic, on the root and inside the walls; move the platter 50 cm", n"Step_AssertFrozenAndMove");
        Add_Step_WaitFrames("the move lands and P follows", 2);
        Add_Step("P moved with the platter", n"Step_AssertRode");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platter.Get_Walls().Num(), 4, "the platter stands four walls");
        Load(_Platter, _P);
    }

    UFUNCTION()
    private void Check_Loaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertFrozenAndMove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_Equals_Int(Get_LoadedCountOf(_P), 1, "OnLoaded fired once for P");

        const auto Landing = TryGet_Loaded(_P);
        Assert_True(Landing.IsSet() && Landing.GetValue().BodyMotion == ECk_MotionType::Kinematic, "P's body read Kinematic when OnLoaded fired");
        Assert_True(Get_IsFrozenOn(_Platter, _P), "P is held, Kinematic and a scene-node child of the root");
        Assert_True(Get_IsInsideWalls(_Platter, _P), f"P's bounds centre lies inside the walls (P at {Get_World(_P).GetLocation()}, root at {Get_PlatterWorld(_Platter).GetLocation()})");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 0, "nothing else is queued or settling");

        _BeforeMove = Get_World(_P).GetLocation();
        Move_Platter(_Platter, Get_PlatterWorld(_Platter).GetLocation() + k_Move);
    }

    UFUNCTION()
    private void Step_AssertRode(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Moved = Get_World(_P).GetLocation() - _BeforeMove;
        Assert_True(Moved.Equals(k_Move, 0.5), f"P moved 50 cm along X with the platter (moved {Moved})");
        Assert_True(Get_IsFrozenOn(_Platter, _P), "P is still frozen on the root");
        Assert_Equals_Int(Get_LoadedCountOf(_P), 1, "the move loaded nothing again");
    }
}
