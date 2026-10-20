// A Drop and a Throw of one held item in the same drain are one launch: OnItemLaunched fires once, as the Drop (it
// drains first), and the hands empty. The Throw's launch of the same item is dropped (LaunchedItem). A bare carrier
// (Hand node, a hotbar of two bag slots, HeldItem, HeldItemUse); a rock. Isolated origin (54800, -16000, -30000).
class UMars_AutoTest_HeldItemUse_DropAndThrowInOneDrainLaunchOnce : UMars_AutoTestRig_Carrier
{
    private const FVector k_Origin = FVector(54800.0, -16000.0, -30000.0);

    private FCk_Handle_HeldItemUse _Use;
    private TArray<FCk_Handle_Item> _LaunchedItems;
    private TArray<EMars_LaunchKind> _LaunchedKinds;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        _Use.BindTo_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnItemLaunched"));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding", 0, 0);
        Add_Step("drop and throw in the same frame", n"Step_DropAndThrow");
        Add_Step_WaitUntil("the item launched and the hands are empty", n"Check_LaunchedAndEmpty", 0, 0);
        Add_Step("one launch, the Drop, of the held rock", n"Step_AssertOneLaunch");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        _LaunchedItems.Add(InItem);
        _LaunchedKinds.Add(InKind);
    }

    UFUNCTION()
    private void Check_Holding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_DropAndThrow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Use.Request_Drop(FMars_Request_HeldItemUse_Drop());
        _Use.Request_Throw(FMars_Request_HeldItemUse_Throw());
    }

    UFUNCTION()
    private void Check_LaunchedAndEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_LaunchedItems.Num() >= 1 && _Use.Has_Fragment(FMars_Fragment_HeldItemUse_Requests) == false
            && ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()));
    }

    UFUNCTION()
    private void Step_AssertOneLaunch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_LaunchedItems.Num(), 1, "OnItemLaunched fired once for the Drop and the Throw of one item");
        if (_LaunchedItems.Num() != 1)
        { return; }

        Assert_True(_LaunchedItems[0] == _Items[0], "the launched item is the held rock");
        Assert_True(_LaunchedKinds[0] == EMars_LaunchKind::Drop, f"the launch is the Drop, which drains first (got {_LaunchedKinds[0] :n})");
    }
}
