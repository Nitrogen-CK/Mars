// The cutting bench cuts meat joints for the pan: its input dock takes whole meat only. Two platters lie beside the real
// station, the input platter with a mushroom slice (already a slice: not a bench input) and a second with the meat slab.
// The dock's kind gate takes every meat food's kind and refuses every vegetable's (the slice, the whole mushroom, the
// spiked berry), and its pure answer refuses the slice's platter KindRejected ("Meat or pickle only") and takes the slab's. Docking
// the slice's platter is refused KindRejected: the dock stays empty and the feed has no source. Docking the slab's docks it
// and the feed draws from it (the Idle state's Source task): one joint available. Isolated origin (13600, -9000, -30000).
class UMars_AutoTest_CuttingStation_InputDockTakesWholeMeatOnly : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(13600.0, -9000.0, -30000.0);

    private FCk_Handle _MeatPlatterEntity;
    private TArray<EMars_PlatterDock_Refusal> _Refusals;
    private int32 _Docks = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MushroomSlice());
        _MeatPlatterEntity = Spawn_LoadedPlatterAt(InHandle, k_OutputPlatterOffset, mars_items::Food_MeatSlab());

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard, feed and docks", n"Check_StationReady", 0, 0);
        Add_Step_WaitUntil("the slice's platter is constructed and its slice landed", n"Check_InputPlatterReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the slab's platter is constructed and its slab landed", n"Check_MeatPlatterReady", k_SlowPolls, 0);
        Add_Step("the gate takes meat and refuses vegetables; dock the slice's platter", n"Step_AssertGateAndDockSlice");
        Add_Step_WaitUntil("the dock answered", n"Check_Answered", 0, 0);
        Add_Step("the slice's platter was refused for its kind and nothing is docked", n"Step_AssertRefused");
        Add_Step("dock the slab's platter", n"Step_DockMeat");
        Add_Step_WaitUntil("the slab's platter is docked and the feed draws from it", n"Check_MeatSourced", k_SlowPolls, 0);
        Add_Step("the feed is sourced with the slab available", n"Step_AssertSourced");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_MeatPlatterReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = Get_IsPlatterConstructed(_MeatPlatterEntity) && _MeatPlatterEntity.As_Platter().Get_HeldCount() == 1;
        if (IsReady)
        { Track_ForCleanup(_MeatPlatterEntity.As_Platter().Get_Held()[0]); }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_AssertGateAndDockSlice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = _InputDock.Get_Spec();
        Assert_True(Spec.Policy.WholeOnly, "the input dock still takes whole pieces only");

        TArray<UMars_Food_Def> Meats;
        Meats.Add(mars::Food_MeatSlab_Mars);
        Meats.Add(mars::Food_Drumstick_Mars);
        Meats.Add(mars::Food_Tentacle_Mars);
        Meats.Add(mars::Food_Puffer_Mars);
        for (auto Meat : Meats)
        { Assert_True(Spec.Policy.Kind.Matches(Meat.Data.Kind), f"the bench takes [{Meat.GetName()}]"); }

        TArray<UMars_Food_Def> Vegetables;
        Vegetables.Add(mars::Food_MushroomSlice_Mars);
        Vegetables.Add(mars::Food_Mushroom_Mars);
        Vegetables.Add(mars::Food_SpikedBerry_Mars);
        for (auto Vegetable : Vegetables)
        { Assert_False(Spec.Policy.Kind.Matches(Vegetable.Data.Kind), f"the bench refuses [{Vegetable.GetName()}]"); }

        const auto SliceRefusal = utils_platter_dock::Get_Refusal(Spec, _InputPlatter);
        Assert_True(SliceRefusal.IsSet() && SliceRefusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected,
            "the slice's platter is refused for its kind");
        Assert_Equals_String(utils_platter_dock::Get_RefusalText(_InputDock.Get_PromptWords(), SliceRefusal).ToString(), "Meat or pickle only", "the dock's prompt says why");
        Assert_False(utils_platter_dock::Get_Refusal(Spec, _MeatPlatterEntity.As_Platter()).IsSet(), "the slab's platter may dock");

        _InputDock.BindTo_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefused"));
        _InputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
        Dock_Input();
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Refusals.Num() > 0 || _Docks > 0);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Refusals.Num(), 1, "one refusal");
        Assert_Equals_Int(_Docks, 0, "nothing docked");
        if (_Refusals.Num() == 1)
        { Assert_True(_Refusals[0] == EMars_PlatterDock_Refusal::KindRejected, f"refused for its kind (got {_Refusals[0] :n})"); }

        Assert_False(_InputDock.Get_IsOccupied(), "the input dock stays empty");
        Assert_False(_Feed.Get_IsSourced(), "the feed has no source");
    }

    UFUNCTION()
    private void Step_DockMeat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _InputDock.Request_Dock(FMars_Request_PlatterDock_Dock(_MeatPlatterEntity.As_WorldItem().Get_HeldItem()));
    }

    UFUNCTION()
    private void Check_MeatSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto MeatPlatter = _MeatPlatterEntity.As_Platter();
        auto Res = OutResult;
        Res.Set(_InputDock.Get_Platter() == MeatPlatter && Get_HasArrived(MeatPlatter) && _InputDock.Get_HasArrived()
            && _Feed.Get_Source() == MeatPlatter);
    }

    UFUNCTION()
    private void Step_AssertSourced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Docks, 1, "one OnDocked");
        Assert_Equals_Int(_Refusals.Num(), 1, "no further refusal");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the slab is available");
    }

    UFUNCTION()
    private void OnDockRefused(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        _Refusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        _Docks += 1;
    }
}
