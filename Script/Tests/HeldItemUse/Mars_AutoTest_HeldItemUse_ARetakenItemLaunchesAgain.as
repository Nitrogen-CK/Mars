// A retaken item launches again: a held rock is dropped; once its world item holds it, the rock is taken back the way a
// pickup stows it; once the hands hold a rock again, a second drop launches it. No Refresh is ever requested: this
// carrier is, like the authority's copy of a player it does not control, a player whose use interactable is never
// built. A bare carrier (Hand node, a hotbar of two bag slots, HeldItem, HeldItemUse). Isolated origin (54800, -19000,
// -30000).
class UMars_AutoTest_HeldItemUse_ARetakenItemLaunchesAgain : UMars_AutoTestRig_Carrier
{
    private const FVector k_Origin = FVector(54800.0, -19000.0, -30000.0);

    private FCk_Handle_HeldItemUse _Use;
    private TArray<FCk_Handle_Item> _LaunchedItems;
    private FCk_Handle_WorldItem _Dropped;
    private FCk_Handle_Item _Retaken;

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
        Add_Step_WaitUntil("the hands hold it", n"Check_HoldingRock", 0, 0);
        Add_Step("drop it", n"Step_Drop");
        Add_Step_WaitUntil("the hands are empty and its world item holds it", n"Check_DroppedAndAdopted", 0, 0);
        Add_Step("take it back from that holder", n"Step_Retake");
        Add_Step_WaitUntil("the hands hold a rock again", n"Check_HoldingRock", 0, 0);
        Add_Step("drop it again", n"Step_DropAgain");
        Add_Step_WaitSeconds("the second drop has had a second", 1.0f);
        Add_Step("it launched twice", n"Step_AssertTwice");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        _LaunchedItems.Add(InItem);
    }

    UFUNCTION()
    private void Check_HoldingRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Item = _HeldItem.Get_CurrentItem();
        auto Res = OutResult;
        Res.Set(ck::IsValid(Item) && Item.Get_Definition() == mars_items::Rock());
    }

    UFUNCTION()
    private void Step_Drop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Use.Request_Drop(FMars_Request_HeldItemUse_Drop());
    }

    // The hands are empty and a World-mode world item's holder holds the rock.
    UFUNCTION()
    private void Check_DroppedAndAdopted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(false);
        if (ck::IsValid(_HeldItem.Get_CurrentItem()) || ck::Is_NOT_Valid(_Items[0]))
        { return; }

        const auto WorldItems = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem");
        for (const auto& Entity : WorldItems)
        {
            if (ck::Is_NOT_Valid(Entity) || Entity.Is_WorldItem() == false)
            { continue; }

            const auto WorldItem = Entity.As_WorldItem();
            if (WorldItem.Get_Mode() != EMars_WorldItem_Mode::World || WorldItem.Get_HeldItem() != _Items[0])
            { continue; }

            _Dropped = WorldItem;
            FCk_Handle DroppedEntity = Entity;
            Track_ForCleanup(DroppedEntity);
            Res.Set(true);
            return;
        }
    }

    UFUNCTION()
    private void Step_Retake(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Dropped.Get_Holder());
    }

    UFUNCTION()
    private void Step_DropAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Retaken = _HeldItem.Get_CurrentItem();
        const auto Line = f"[ConsumeTest] ARetakenItemLaunchesAgain retaken first={_Items[0].ToString()} retaken={_Retaken.ToString()} same={_Retaken == _Items[0]}";
        Log(Line);
        _Use.Request_Drop(FMars_Request_HeldItemUse_Drop());
    }

    UFUNCTION()
    private void Step_AssertTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Line = f"[ConsumeTest] ARetakenItemLaunchesAgain launched={_LaunchedItems.Num()} same={_Retaken == _Items[0]}";
        Log(Line);
        Assert_Equals_Int(_LaunchedItems.Num(), 2, "OnItemLaunched fired twice: the retaken rock launched again");
    }
}
