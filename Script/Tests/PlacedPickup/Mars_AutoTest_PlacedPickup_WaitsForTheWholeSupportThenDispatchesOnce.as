class UMars_AutoTest_PlacedPickup_WaitsForTheWholeSupportThenDispatchesOnce : UMars_AutoTestRig_PlacedPickup
{
    private FCk_Handle_Item _Item;
    private TOptional<FVector> _LastPosition;
    private int32 _StillPolls = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_PlacedPickup_TestSpec();
        Spec.Origin = FVector(-62000.0, 362000.0, -41000.0);
        Spec.Definition = mars_items::Ration();
        Spec.Id = n"PlacedPickup.SupportStages";
        Build_Proxy(InHandle, Spec);
        Add_Step_WaitUntil("proxy owns its readiness timer", n"Check_ProxyWaiting");
        Add_Step_WaitSeconds("several absent-support polls", 0.2f);
        Add_Step("absent support creates no item; add wrong-height floor", n"Step_WrongFloor");
        Add_Step_WaitUntil("wrong floor exists in real Jolt", n"Check_WrongFloor");
        Add_Step_WaitSeconds("several wrong-height polls", 0.2f);
        Add_Step("wrong height creates no item; replace with four witnesses", n"Step_PartialFloor");
        Add_Step_WaitUntil("exactly one footprint corner is absent", n"Check_PartialFloor");
        Add_Step_WaitSeconds("several missing-corner polls", 0.2f);
        Add_Step("missing corner creates no item; complete support", n"Step_CompleteFloor");
        Add_Step_WaitUntil("original item has a seeded holder and added Jolt body", n"Check_PlacedReady", 900, 0);
        Add_Step_WaitUntil("real item settles on its support", n"Check_Settled", 900, 0);
        Add_Step_WaitSeconds("support remains ready after dispatch", 0.2f);
        Add_Step("one original item; consume with the original inventory remove policy", n"Step_Consume");
        Add_Step_WaitUntil("item and emptied transient WorldItem end", n"Check_Consumed");
        Add_Step_WaitSeconds("ready support never rearms the spent fixture", 0.2f);
        Add_Step("consumption does not spawn another pickup", n"Step_NoRespawn");
        Add_Step("destroy fixture and real support", n"Step_DestroyFixture");
        Add_Step_WaitUntil("fixture and support gone", n"Check_FixtureGone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WrongFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NoPickup();
        Assert_Equals_Int(Get_SupportMask(), 0, "no support exists");
        Add_Support(_SupportTop - FVector(0.0, 0.0, 4.0), FVector2D(100.0, 100.0));
    }

    UFUNCTION()
    private void Check_WrongFloor(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Hit = utils_jolt_static_world::Get_RayCastStaticWorld(_SupportTop + FVector(0.0, 0.0, 5.0), _SupportTop - FVector(0.0, 0.0, 5.0));
        Result.Set(Hit.Get_HasHit() && Math::Abs(Hit.Get_Position().Z - (_SupportTop.Z - 4.0)) < 0.1);
    }

    UFUNCTION()
    private void Step_PartialFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NoPickup();
        Assert_Equals_Int(Get_SupportMask(), 0, "a real lower hit is not the authored support plane");
        Destroy_Floors();
        const auto Points = Get_Witnesses();
        for (int32 Index = 0; Index < 4; ++Index)
        { Add_Support(Points[Index], Index == 0 ? FVector2D(25.0, 25.0) : FVector2D(8.0, 8.0)); }
    }

    UFUNCTION()
    private void Check_PartialFloor(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(Get_SupportMask() == 15); }

    UFUNCTION()
    private void Step_CompleteFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NoPickup();
        Assert_Equals_Int(Get_SupportMask(), 15, "all but one corner is not sufficient");
        Add_Support(Get_Witnesses()[4], FVector2D(8.0, 8.0));
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Position = utils_transform::Get_EntityCurrentLocation(_Placed.As_Transform());
        const auto Still = _LastPosition.IsSet() && Position.Distance(_LastPosition.GetValue()) < 0.15;
        _StillPolls = Still ? _StillPolls + 1 : 0;
        _LastPosition = TOptional<FVector>(Position);
        auto Result = OutResult;
        Result.Set(_StillPolls >= 10 && Position.Z >= _SupportTop.Z && Position.Z <= _SupportTop.Z + 25.0);
    }

    UFUNCTION()
    private void Step_Consume(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 1, "exactly one original item exists");
        Assert_True(utils_entity_tag::Has(_Proxy, n"TAG_MarsPlacedPickupDispatched"), "fixture remains dispatched");
        Assert_Equals_Int(utils_timer::ForEach_Timer(_Proxy, FInstancedStruct()).Num(), 0, "readiness timer stopped after dispatch");
        _Item = _Placed.Get_HeldItem();
        Assert_True(_Item.Get_Definition() == mars_items::Ration(), "original ration definition retained");
        auto Inventory = _Item.Get_ParentInventory();
        auto Remove = FCk_Request_Inventory_RemoveItem(_Item);
        Remove.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Inventory.Request_RemoveItem(Remove, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    UFUNCTION()
    private void Check_Consumed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(ck::Is_NOT_Valid(_Item) && ck::Is_NOT_Valid(_Placed)); }

    UFUNCTION()
    private void Step_NoRespawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 0, "consumed pickup is never replaced");
        Assert_True(utils_entity_tag::Has(_Proxy, n"TAG_MarsPlacedPickupDispatched"), "proxy retains its one-shot state");
        Assert_Equals_Int(Get_SupportMask(), 31, "support still exists; absence of a replacement is deliberate");
    }
}
