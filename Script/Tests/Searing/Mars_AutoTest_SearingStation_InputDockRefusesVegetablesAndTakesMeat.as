// The searing station's raw platter dock takes meat only. Two platters lie beside the real station, one with the meat slab
// and one with a mushroom slice. Docking the mushroom one is refused KindRejected: the dock stays empty and the feed has no
// source. Docking the meat one docks it, and the feed draws from it (the station's Source task sets it on the dock's
// OnDocked): sourced, one piece available.
class UMars_AutoTest_SearingStation_InputDockRefusesVegetablesAndTakesMeat : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(12000.0, -12000.0, -30000.0);
    private const FVector k_MeatOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_MushroomOffset = FVector(0.0, 300.0, 0.0);

    private FCk_Handle _Meat;
    private FCk_Handle _Mushroom;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Searing(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Meat = Spawn_Platter(InHandle, k_MeatOffset, mars::Food_MeatSlab_Mars);
        _Mushroom = Spawn_Platter(InHandle, k_MushroomOffset, mars::Food_MushroomSlice_Mars);

        Add_Step_WaitUntil("the station composed its Searing, feed and docks, and the pan body exists", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("both platters are constructed and their joints landed", n"Check_PlattersReady", 0, 10.0f);
        Add_Step("dock the mushroom platter on the raw platter dock", n"Step_DockMushroom");
        Add_Step_WaitUntil("the dock answered", n"Check_Refused", 0, 5.0f);
        Add_Step("it was refused for its kind and nothing is docked", n"Step_AssertRefused");
        Add_Step("dock the meat platter on the raw platter dock", n"Step_DockMeat");
        Add_Step_WaitUntil("the meat platter is docked and the feed draws from it", n"Check_MeatSourced", 0, 5.0f);
        Add_Step("the feed is sourced with the slab available", n"Step_AssertSourced");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Meat, 1) && Get_IsPlatterReady(_Mushroom, 1));
    }

    UFUNCTION()
    private void Step_DockMushroom(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Track_Held(_Meat);
        Track_Held(_Mushroom);
        Dock(_InputDock, _Mushroom);
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_DockRefusals.Num() > 0 || _Docked.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DockRefusals.Num(), 1, "one refusal");
        Assert_Equals_Int(_Docked.Num(), 0, "nothing docked");
        if (_DockRefusals.Num() == 1)
        { Assert_True(_DockRefusals[0] == EMars_PlatterDock_Refusal::KindRejected, f"refused for its kind (got {_DockRefusals[0] :n})"); }

        Assert_False(_InputDock.Get_IsOccupied(), "the raw platter dock stays empty");
        Assert_False(_Feed.Get_IsSourced(), "the feed has no source");
        Assert_True(utils_platter_dock::Get_RefusalText(_InputDock.Get_Spec(), TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::KindRejected)).ToString() == "Meat only",
            "the dock's prompt says why");
    }

    UFUNCTION()
    private void Step_DockMeat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_InputDock, _Meat);
    }

    UFUNCTION()
    private void Check_MeatSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Meat) && _Feed.Get_IsSourced());
    }

    UFUNCTION()
    private void Step_AssertSourced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Docked.Num(), 1, "one OnDocked");
        Assert_True(_Docked.Num() == 1 && _Docked[0] == _Meat.As_Platter(), "the meat platter docked");
        Assert_Equals_Int(_DockRefusals.Num(), 1, "no further refusal");
        Assert_True(_Feed.Get_Source() == _Meat.As_Platter(), "the feed draws from the meat platter");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the slab is available");
    }
}

class AMars_AutoTest_SearingStation_InputDockRefusesVegetablesAndTakesMeat_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_InputDockRefusesVegetablesAndTakesMeat;
}
