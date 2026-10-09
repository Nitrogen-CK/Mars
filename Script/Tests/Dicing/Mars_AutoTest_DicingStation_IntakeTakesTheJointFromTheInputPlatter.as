// The intake takes the meat joint off the docked input platter with nobody operating the station: the platter empties and
// the same piece lies on the board at the pile (world XY within 0.5 cm), yawed by its food's layout (within 0.5 deg), no
// longer riding the platter, still shown and still whole. An operator taking the station afterwards changes nothing: the
// joint was placed once.
class UMars_AutoTest_DicingStation_IntakeTakesTheJointFromTheInputPlatter : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(16000.0, -9000.0, -30000.0);

    private FCk_Handle_FoodPiece _Joint;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars::Food_MeatSlab_Mars);

        Add_Step_WaitUntil("the station composed its Dicing, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the input platter is constructed and its joint landed", n"Check_InputPlatterReady", 0, 10.0f);
        Add_Step("remember the platter's joint and dock the platter", n"Step_DockTheJoint");
        Add_Step_WaitUntil("the input platter is docked", n"Check_InputDocked", 0, 5.0f);
        Add_Step_WaitUntil("the intake laid one shown joint on the board", n"Check_JointOnBoard", 0, 5.0f);
        Add_Step_WaitFrames("the pile pose has landed", 2);
        Add_Step("nobody operates the station: it is Idle", n"Step_AssertIdle");
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step_WaitFrames("a second intake would have drained by now", 5);
        Add_Step("the platter is empty; the joint lies at the pile in its layout, shown and whole", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DockTheJoint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _InputPlatter.Get_Held()[0];
        Dock_Input();
    }

    UFUNCTION()
    private void Step_AssertIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Idle,
            "the joint landed while the station was Idle");
        Assert_True(ck::Is_NOT_Valid(_Station.Get_Operator()), "nobody operates the station");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 0, "the input platter is empty");
        Assert_Equals_Int(_InputPlatter.Get_PendingCount(), 0, "nothing waits to land on the input platter");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Joint, "the board holds the platter's joint");
        Assert_Equals_Int(_Placed.Num(), 1, "the joint was placed once");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint no longer names a platter");
        Assert_False(ck::IsValid(Get_Parent(_Joint)), "the joint no longer rides the platter");
        Assert_True(_Board.Get_IsUntouched(), "a whole joint on an empty board leaves it untouched");
        Assert_True(_Joint.Get_IsWhole(), "the joint is still whole");
        Assert_True(Get_IsShown(_Joint), "the joint is still shown");

        const auto StationWorld = Get_StationWorld();
        const auto Pile = (utils_dicing::Get_PileLocal() * StationWorld).GetLocation();
        const auto JointWorld = Get_World(_Joint);
        const auto Offset = JointWorld.GetLocation() - Pile;
        Assert_True(Math::Abs(Offset.X) <= 0.5 && Math::Abs(Offset.Y) <= 0.5, f"the joint lies at the pile ({JointWorld.GetLocation()} vs {Pile})");

        const auto Yaw = JointWorld.Rotator().Yaw - StationWorld.Rotator().Yaw;
        const auto YawError = Math::Abs(Math::UnwindDegrees(Yaw - _Food.Layout.YawDegrees));
        Assert_True(YawError <= 0.5, f"the joint is yawed by its layout ({Yaw} vs {_Food.Layout.YawDegrees} deg)");
        Assert_True(JointWorld.GetScale3D().Equals(FVector::OneVector, 0.0001), f"the joint is unscaled ({JointWorld.GetScale3D()})");
    }
}
