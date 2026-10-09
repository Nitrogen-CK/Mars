// A piece with a Dynamic body lands only once its body reads Kinematic, and then rides the platter: moving the platter moves
// the piece by the same offset, so the body follows the ECS transform rather than the other way.
class UMars_AutoTest_Platter_LoadedBodyGoesKinematicAndRides : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -13000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_JoltBody _Body;
    private FVector _BeforeMove;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, 15.0, 0.0), k_Origin), Make_PlatterSpec(1, 0.0f));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.8);

        Add_Step_WaitUntil("P is Ready", n"Check_Ready");
        Add_Step("give P a dynamic body", n"Step_GiveBody");
        Add_Step_WaitUntil("P's body is added", n"Check_BodyAdded");
        Add_Step("load P", n"Step_Load");
        Add_Step_WaitUntil("P landed", n"Check_Landed");
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("P landed kinematic; move the platter 150 cm along X", n"Step_AssertLandedAndMove");
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
    private void Step_GiveBody(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Body = Give_Body(_P);
    }

    UFUNCTION()
    private void Check_BodyAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_Body));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_jolt_body::Get_MotionType(_Body) == ECk_MotionType::Dynamic, "P's body starts Dynamic");
        Load(_Platter, _P);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertLandedAndMove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");

        const auto Landing = TryGet_Loaded(_P);
        Assert_True(Landing.IsSet() && Landing.GetValue().BodyMotion.IsSet()
            && Landing.GetValue().BodyMotion.GetValue() == ECk_MotionType::Kinematic, "P's body read Kinematic when it landed");

        const auto Expected = Get_SlotWorld(_Platter, _P, 0).GetLocation();
        Assert_True(Get_World(_P).GetLocation().Equals(Expected, 0.5), f"P rests at its slot ({Get_World(_P).GetLocation()} vs {Expected})");

        _BeforeMove = Get_World(_P).GetLocation();
        Move_Platter(_Platter, Get_PlatterWorld(_Platter).GetLocation() + FVector(150.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Step_AssertRode(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Moved = Get_World(_P).GetLocation() - _BeforeMove;
        Assert_True(Moved.Equals(FVector(150.0, 0.0, 0.0), 0.5), f"P moved 150 cm along X with the platter (moved {Moved})");
        Assert_True(utils_jolt_body::Get_MotionType(_Body) == ECk_MotionType::Kinematic, "P's body is still Kinematic");
    }
}
