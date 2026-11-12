// The server spawns the real cutting station and reports once it is constructed: its docks have composed, its feed draws
// from its Input dock and its board exists. On the client the station has both docks, a CookingFeed with no input dock, a
// FoodBoard and a Cutting, and no ensure was raised since the test began.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ARealCuttingStationComposesOnBothMachines
class UCk_AutoTest_Net_PlatterDock_ARealCuttingStationComposesOnBothMachines : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 247000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _StationKind = EMars_TESTONLY_NetDockStationKind::CuttingStation;
        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    protected void On_ServerPlatterReady() override
    {
        Spawn_ServerStation();
    }

    protected void On_ServerDocksReady() override
    {
        const auto IsFed = _Station.Is_CookingFeed() && _Station.As_CookingFeed().Get_InputDock() == _InputDock;
        Assert_True(utils_platter_dock::Get_AreDocksComposed(_Station), "the server's docks have composed");
        Assert_True(IsFed, "the server's feed draws from its Input dock");
        Assert_True(_Station.Is_FoodBoard(), "the server's station has its board");
        Publish_Location(1, FVector::ZeroVector);
        End_DockServer(f"{Describe_ConstructFrames()} fed={IsFed} board={_Station.Is_FoodBoard()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto HasFeed = _Station.Is_CookingFeed();
        const auto FeedDock = HasFeed ? _Station.As_CookingFeed().Get_InputDock() : FCk_Handle_PlatterDock();

        Assert_True(ck::IsValid(_InputDock) && ck::IsValid(_OutputDock), "the client's station has both docks");
        Assert_True(HasFeed, "the client's station has a CookingFeed");
        Assert_True(ck::Is_NOT_Valid(FeedDock), f"the client's feed has no input dock (got [{FeedDock.ToString()}])");
        Assert_True(_Station.Is_FoodBoard(), "the client's station has a FoodBoard");
        Assert_True(_Station.Is_Cutting(), "the client's station has a Cutting");
        End_DockClient(f"feed={HasFeed} feedDock=[{FeedDock.ToString()}] board={_Station.Is_FoodBoard()} cutting={_Station.Is_Cutting()}");
    }
}
