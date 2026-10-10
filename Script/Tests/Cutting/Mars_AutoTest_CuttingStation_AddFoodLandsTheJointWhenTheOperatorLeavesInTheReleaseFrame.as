// The operator leaving in the frame the feed releases the joint strands nothing. The meat platter docks and an operator takes
// the station and adds food; in the frame the feed asks for the release (the joint let go from the glove, the Operated
// bridge placing it) the operator leaves. Whichever drains first, the board's answer or the state change, the joint lands on
// the board: the Idle bridge takes the release in flight over. The station is Idle, the board holds the joint,
// the platter is empty, the joint was placed once and the feed admitted it and is Idle. Isolated origin (19200, -9000,
// -30000).
class UMars_AutoTest_CuttingStation_AddFoodLandsTheJointWhenTheOperatorLeavesInTheReleaseFrame : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(19200.0, -9000.0, -30000.0);

    private FCk_Handle_FoodPiece _Joint;
    private bool _LeaveOnRelease = false;
    private bool _WasOperatedAtLeave = false;
    private int32 _BoardHeldAtLeave = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard, feed and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the input platter is constructed and its joint landed", n"Check_InputPlatterReady", 0, 10.0f);
        Add_Step("dock the input platter", n"Step_DockInput");
        Add_Step_WaitUntil("the input platter is docked", n"Check_InputDocked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step_WaitUntil("the feed draws from the docked platter, its joint frozen", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("add food; leave in the frame the feed releases", n"Step_AddFoodAndLeaveOnRelease");
        Add_Step_WaitUntil("the station is Idle, the joint lies on the board and the glove is back", n"Check_IdleWithJoint", 0, 5.0f);
        Add_Step_WaitFrames("a second place would have drained by now", 5);
        Add_Step("the joint landed once; the platter is empty", n"Step_Assert");
        Run_Steps(InHandle);
    }

    // Bound after the Operated bridge (it bound on enter): the bridge places the joint first, then the operator leaves.
    UFUNCTION()
    private void Step_AddFoodAndLeaveOnRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _InputPlatter.Get_Held()[0];
        _LeaveOnRelease = true;
        _Feed.BindTo_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseLeave"));
        Add_Food();
    }

    UFUNCTION()
    private void OnReleaseLeave(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease)
    {
        if (_LeaveOnRelease == false)
        { return; }

        _LeaveOnRelease = false;
        _WasOperatedAtLeave = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Cutting_Operated;
        _BoardHeldAtLeave = _Board.Get_HeldCount();
        Leave();
    }

    UFUNCTION()
    private void Check_IdleWithJoint(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsIdle = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Cutting_Idle;

        auto Res = OutResult;
        Res.Set(IsIdle && _Board.Get_HeldCount() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_WasOperatedAtLeave, "the operator left while the station was Operated");
        Assert_Equals_Int(_BoardHeldAtLeave, 0, "the board was empty when the operator left");
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Cutting_Idle, "the station is Idle");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Joint, "the board holds the platter's joint");
        Assert_Equals_Int(_Placed.Num(), 1, "the joint was placed once");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the feed counted one admission");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 0, "the input platter is empty");
        Assert_Equals_Int(_InputPlatter.Get_PendingCount(), 0, "nothing waits to land on the input platter");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint names no platter");
        Assert_False(ck::IsValid(Get_Parent(_Joint)), "the joint no longer rides the platter");
        Assert_True(Get_IsShown(_Joint), "the joint is still shown");
    }
}
