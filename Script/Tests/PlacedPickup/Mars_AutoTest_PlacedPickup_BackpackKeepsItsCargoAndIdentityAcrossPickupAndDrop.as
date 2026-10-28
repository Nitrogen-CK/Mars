class UMars_AutoTest_PlacedPickup_BackpackKeepsItsCargoAndIdentityAcrossPickupAndDrop : UMars_AutoTestRig_PlacedPickup
{
    private FCk_Handle_Item _Item;
    private FCk_Handle_Backpack _Backpack;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, FVector(-65000.0, 362000.0, -41000.0));
        Add_Hotbar(_Carrier, 1);
        auto Spec = FMars_PlacedPickup_TestSpec();
        Spec.Origin = FVector(-64600.0, 362000.0, -41000.0);
        Spec.SupportOffset = -5.0;
        Spec.HalfExtents = FVector2D(75.0, 75.0);
        Spec.Definition = mars_items::Backpack();
        Spec.Id = n"PlacedPickup.Backpack";
        Build_Proxy(InHandle, Spec);
        Add_Step_WaitUntil("proxy waiting with no support", n"Check_ProxyWaiting");
        Add_Step("add actual backpack support", n"Step_Support");
        Add_Step_WaitUntil("original specialized Backpack is composed", n"Check_BackpackReady", 900, 0);
        Add_Step("same original definition and all cargo slots; stow pack", n"Step_Pickup");
        Add_Step_WaitUntil("same pack carried with added kinematic body", n"Check_Carried", 900, 0);
        Add_Step_WaitSeconds("readiness cannot create another carried pack", 0.2f);
        Add_Step("one pack after pickup; release original", n"Step_Drop");
        Add_Step_WaitUntil("same pack returns to world mount", n"Check_Dropped", 900, 0);
        Add_Step_WaitSeconds("readiness cannot create another dropped pack", 0.2f);
        Add_Step("identity and cargo survived pickup/drop", n"Step_Assert");
        Add_Step("destroy completed proxy and child", n"Step_DestroyFixture");
        Add_Step_WaitUntil("completed child follows proxy teardown", n"Check_FixtureGone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Support(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NoPickup();
        Add_Support(_SupportTop, FVector2D(160.0, 160.0));
    }

    UFUNCTION()
    private void Check_BackpackReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_PlacedReady() == false || _Placed.Is_Backpack() == false)
        { Result.Set(false); return; }
        _Backpack = _Placed.As_Backpack();
        const UMars_ItemTrait_Backpack Trait = mars_items::Backpack().Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
        Result.Set(_Backpack.Get_CargoSlotCount() == Trait.CargoSlots.Num());
    }

    UFUNCTION()
    private void Step_Pickup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _Placed.Get_Item();
        Assert_True(_Placed.Get_Persistence() == EMars_WorldItem_Persistence::Persistent, "pack keeps its original persistence");
        Assert_True(utils_entity_script::Get_ScriptClass(_Placed.As_EntityScript()) == UMars_Backpack_EntityScript,
            "Request_SpawnWorld preserved definition-selected Backpack script");
        Assert_True(_Item.Get_Definition() == mars_items::Backpack(), "original backpack definition");
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 1, "one original specialized child");
        for (int32 Index = 0; Index < _Backpack.Get_CargoSlotCount(); ++Index)
        { Assert_True(ck::IsValid(_Backpack.Get_CargoSlot(Index)), "actual cargo slot exists"); }
        // The same entity-preserving transfer used by the pickup task; physical Use/glove input is covered separately.
        auto Holder = _Placed.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Item, _Hotbar.Get_BackpackSlot()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Carried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Hotbar.Get_BackpackItem() == _Item && _Placed.Get_Item() == _Item
            && _Placed.Get_Mount() == EMars_WorldItem_Mount::Carried && _Placed.Get_IsSettled()
            && _Placed.Get_Body().Get_MotionType() == ECk_MotionType::Kinematic);
    }

    UFUNCTION()
    private void Step_Drop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 1, "pickup never rearms the proxy");
        Assert_True(utils_entity_tag::Has(_Proxy, n"TAG_MarsPlacedPickupDispatched"), "proxy remains dispatched after pickup");
        _Placed.Request_Release(FMars_Request_WorldItem_Release(FVector(0.0, 0.0, 20.0), FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_Dropped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Placed.Get_Mount() == EMars_WorldItem_Mount::World && _Placed.Get_HeldItem() == _Item
            && _Hotbar.Get_BackpackSlot().Get_NumItems() == 0 && _Placed.Get_Body().Get_MotionType() == ECk_MotionType::Dynamic);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 1, "drop never rearms the proxy");
        Assert_True(_Item.Get_PersistentWorldItem() == _Placed, "drop retains the same persistent body");
        const UMars_ItemTrait_Backpack Trait = mars_items::Backpack().Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
        Assert_Equals_Int(_Backpack.Get_CargoSlotCount(), Trait.CargoSlots.Num(), "all original cargo slots survived");
        Assert_Equals_Int(utils_timer::ForEach_Timer(_Proxy, FInstancedStruct()).Num(), 0, "no readiness timer survives dispatch");
    }
}
