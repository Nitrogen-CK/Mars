// A whole food the board holds cannot be taken by hand: the board's ledger would never notice. The meat slab (a food item)
// has its pickup live on the input platter; once the feed places it on the board (nobody operating: the feed's bridge runs
// in Idle too) the pickup reads disabled. Swept onto the docked tray (a handoff release), the slab gets its pickup back.
class UMars_AutoTest_CuttingStation_AJointOnTheBoardCannotBePickedUp : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(16800.0, -21000.0, -30000.0);

    private FCk_Handle_FoodPiece _Joint;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());
        Spawn_OutputPlatter(InHandle);

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the input platter is constructed and its joint landed", n"Check_InputPlatterReady", 0, 10.0f);
        Add_Step_WaitUntil("the finished tray is constructed", n"Check_OutputPlatterReady", 0, 10.0f);
        Add_Step("the joint on the input platter can be picked up", n"Step_AssertPickupLive");
        Add_Step("dock the input platter", n"Step_DockInput");
        Add_Step_WaitUntil("the input platter is docked", n"Check_InputDocked", 0, 5.0f);
        Add_Step_WaitUntil("the feed draws from the docked platter, its joint frozen", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("add food", n"Step_AddFood");
        Add_Step_WaitUntil("the feed laid the joint on the board", n"Check_JointOnBoard", 0, 5.0f);
        Add_Step_WaitUntil("the joint's pickup reads disabled", n"Check_PickupDisabled", 0, 1.0f);
        Add_Step_WaitFrames("the board holds the joint a while", 10);
        Add_Step("the joint on the board cannot be picked up", n"Step_AssertPickupDisabled");
        Add_Step("dock the finished tray", n"Step_DockOutput");
        Add_Step_WaitUntil("the finished tray is docked", n"Check_OutputDocked", 0, 5.0f);
        Add_Step("sweep the joint to the tray", n"Step_Sweep");
        Add_Step_WaitUntil("the board let the joint go", n"Check_Released", 0, 3.0f);
        Add_Step_WaitUntil("the released joint's pickup reads enabled", n"Check_PickupEnabled", 0, 1.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertPickupLive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _InputPlatter.Get_Held()[0];
        FCk_Handle JointEntity = _Joint;
        Assert_True(JointEntity.Is_WorldItem(), "the joint is a food item's entity");
        if (JointEntity.Is_WorldItem() == false)
        { return; }

        Assert_True(Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Enable, "the joint's pickup is live on the platter");
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
        Assert_True(_Board.Get_Held().Contains(_Joint), "the board holds the joint");
        Assert_True(Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Disable, "the board's joint cannot be picked up");
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Contains(_Joint));
    }

    UFUNCTION()
    private void Check_PickupEnabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Enable);
    }

    private FCk_Handle_Interactable Get_Pickup() const
    {
        FCk_Handle JointEntity = _Joint;
        return JointEntity.As_WorldItem().Get_Pickup();
    }
}
