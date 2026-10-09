// The operator leaving in the frame the intake asks the input platter for its joint strands nothing. An operator takes the
// empty station; the meat platter then docks, and in the frame the dock reports it (the frame the Operated intake asks for
// the unload) the operator leaves. Whichever drains first, the unload or the state change, the joint lands on the board:
// the Idle intake asks again on enter and the platter drains the two as one. The station is Idle, the board holds the
// joint, the platter is empty and the joint was placed once.
class UMars_AutoTest_DicingStation_IntakeLandsTheJointWhenTheOperatorLeavesInTheUnloadFrame : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(19200.0, -9000.0, -30000.0);

    private FCk_Handle_FoodPiece _Joint;
    private bool _LeaveOnDock = false;
    private bool _WasOperatedAtLeave = false;
    private int32 _BoardHeldAtLeave = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars::Food_MeatSlab_Mars);

        Add_Step_WaitUntil("the station composed its Dicing, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the input platter is constructed and its joint landed", n"Check_InputPlatterReady", 0, 10.0f);
        Add_Step("an operator takes the empty station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step("dock the input platter; leave in the frame it docks", n"Step_DockAndLeaveOnDocked");
        Add_Step_WaitUntil("the station is Idle and the joint lies on the board", n"Check_IdleWithJoint", 0, 5.0f);
        Add_Step_WaitUntil("the input platter has arrived on its dock", n"Check_InputDocked", 0, 5.0f);
        Add_Step_WaitFrames("a second intake would have drained by now", 5);
        Add_Step("the joint landed once; the platter is empty", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DockAndLeaveOnDocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _InputPlatter.Get_Held()[0];
        _LeaveOnDock = true;
        _InputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnInputDockedLeave"));
        Dock_Input();
    }

    // The Operated intake hears the same broadcast and asks the platter for the joint in this frame.
    UFUNCTION()
    private void OnInputDockedLeave(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (_LeaveOnDock == false)
        { return; }

        _LeaveOnDock = false;
        _WasOperatedAtLeave = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Operated;
        _BoardHeldAtLeave = _Board.Get_HeldCount();
        Leave();
    }

    UFUNCTION()
    private void Check_IdleWithJoint(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsIdle = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Idle;

        auto Res = OutResult;
        Res.Set(IsIdle && _Board.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_WasOperatedAtLeave, "the operator left while the station was Operated");
        Assert_Equals_Int(_BoardHeldAtLeave, 0, "the board was empty when the operator left");
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Idle, "the station is Idle");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Joint, "the board holds the platter's joint");
        Assert_Equals_Int(_Placed.Num(), 1, "the joint was placed once");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 0, "the input platter is empty");
        Assert_Equals_Int(_InputPlatter.Get_PendingCount(), 0, "nothing waits to land on the input platter");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint names no platter");
        Assert_False(ck::IsValid(Get_Parent(_Joint)), "the joint no longer rides the platter");
        Assert_True(Get_IsShown(_Joint), "the joint is still shown");
    }
}
