// A whole food the pan holds cannot be taken by hand: the pan's ledger would never notice. The meat slab (a food item, its
// pickup live on the raw platter) is fed into the searing pan; once the kernel admits it the feed bridge has disabled its
// pickup. Taken out onto the tray, its pickup is enabled again, so the slab can be picked off the tray.
class UMars_AutoTest_SearingStation_AnAdmittedJointCannotBePickedUp : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(26000.0, -21000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Slab;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Searing(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, mars_items::Food_MeatSlab());
        _Tray = Spawn_Platter(InHandle, k_TrayOffset, nullptr);

        Add_Step_WaitUntil("the station composed its Searing, feed and docks, and the pan body exists", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("both platters are constructed and the slab landed on the raw one", n"Check_PlattersReady", 0, 10.0f);
        Add_Step("dock the meat platter as raw and the empty one as the tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", 0, 5.0f);
        Add_Step("the slab on the raw platter can be picked up", n"Step_AssertPickupLive");
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 3.0f);
        Add_Step("one add-food press", n"Step_Press");
        Add_Step_WaitUntil("the kernel admitted the slab", n"Check_Admitted", 0, 5.0f);
        Add_Step_WaitUntil("the admitted slab's pickup reads disabled", n"Check_PickupDisabled", 0, 1.0f);
        Add_Step_WaitSeconds("the pan holds the slab a while", 0.5f);
        Add_Step("the slab's pickup is still disabled", n"Step_AssertPickupDisabled");
        Add_Step("take the slab out by name", n"Step_TakeOut");
        Add_Step_WaitUntil("the slab was handed back", n"Check_TakenOut", 0, 5.0f);
        Add_Step_WaitUntil("the taken-out slab's pickup reads enabled", n"Check_PickupEnabled", 0, 1.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 1) && Get_IsPlatterReady(_Tray, 0));
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Track_Held(_Raw);
        _Slab = _Raw.As_Platter().Get_Held()[0];
        Dock(_InputDock, _Raw);
        Dock(_OutputDock, _Tray);
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Raw) && Get_IsDocked(_OutputDock, _Tray));
    }

    UFUNCTION()
    private void Step_AssertPickupLive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle SlabEntity = _Slab;
        Assert_True(SlabEntity.Is_WorldItem(), "the slab is a food item's entity");
        if (SlabEntity.Is_WorldItem() == false)
        { return; }

        Assert_True(Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Enable, "the slab's pickup is live on the raw platter");
    }

    UFUNCTION()
    private void Check_OperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 1);
    }

    UFUNCTION()
    private void Step_Press(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 1 && Get_SettleCount(EMars_CookingFeed_Settle::Admitted) == 1);
    }

    UFUNCTION()
    private void Check_PickupDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Step_AssertPickupDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_PieceHandle(Get_PieceIds()[0]) == _Slab, "the pan holds the slab");
        Assert_True(Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Disable, "the pan's slab cannot be picked up");
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Request_TakeOut(_Slab);
    }

    UFUNCTION()
    private void Check_TakenOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() == 1 && Get_PieceIds().Num() == 0);
    }

    UFUNCTION()
    private void Check_PickupEnabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Enable);
    }

    private FCk_Handle_Interactable Get_Pickup() const
    {
        FCk_Handle SlabEntity = _Slab;
        return SlabEntity.As_WorldItem().Get_Pickup();
    }
}

class AMars_AutoTest_SearingStation_AnAdmittedJointCannotBePickedUp_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_AnAdmittedJointCannotBePickedUp;
}
