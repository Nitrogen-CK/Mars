class UMars_AutoTest_PlacedPickup_TeardownCancelsWaitingAndPendingChildren : UMars_AutoTestRig_PlacedPickup
{
    private FCk_Handle _WaitingProxy;
    private FCk_Handle_Timer _WaitingTimer;
    private FCk_Handle _PendingChild;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_PlacedPickup_TestSpec();
        Spec.Origin = FVector(-68000.0, 362000.0, -41000.0);
        Spec.Definition = mars_items::Ration();
        Spec.Id = n"PlacedPickup.DestroyWaiting";
        Build_Proxy(InHandle, Spec);
        Add_Step_WaitUntil("waiting proxy owns a readiness timer", n"Check_ProxyWaiting");
        Add_Step("destroy owner before any support exists", n"Step_DestroyWaiting");
        Add_Step_WaitUntil("waiting owner and timer ended", n"Check_WaitingGone");
        Add_Step("dispatch definition-selected child whose construction pauses", n"Step_BuildPending");
        Add_Step_WaitUntil("owned child reached Continue before WorldItem composition", n"Check_Pending", 900, 0);
        Add_Step("destroy owner during pending construction", n"Step_DestroyPending");
        Add_Step_WaitUntil("pending child and proxy ended", n"Check_PendingGone");
        Add_Step_WaitSeconds("no pending continuation returns after teardown", 0.2f);
        Add_Step("nothing survives waiting or pending teardown", n"Step_AssertGone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DestroyWaiting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NoPickup();
        _WaitingProxy = _Proxy;
        _WaitingTimer = utils_timer::ForEach_Timer(_Proxy, FInstancedStruct())[0];
        utils_entity_lifetime::Request_DestroyEntity(_Proxy);
    }

    UFUNCTION()
    private void Check_WaitingGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(ck::Is_NOT_Valid(_WaitingProxy) && ck::Is_NOT_Valid(_WaitingTimer)); }

    UFUNCTION()
    private void Step_BuildPending(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_PlacedPickup_TestSpec();
        Spec.Origin = FVector(-69000.0, 362000.0, -41000.0);
        Spec.Definition = utils_placed_pickup_test::Get_PendingDefinition();
        Spec.Id = n"PlacedPickup.DestroyPending";
        Build_Proxy(InHandle, Spec);
        Add_Support(_SupportTop, FVector2D(100.0, 100.0));
    }

    UFUNCTION()
    private void Check_Pending(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        for (auto Entity : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsPlacedPickupPendingFixture"))
        {
            if (ck::IsValid(Entity) && utils_entity_lifetime::Get_LifetimeOwner(Entity) == _Proxy)
            { _PendingChild = Entity; break; }
        }
        Result.Set(ck::IsValid(_PendingChild) && utils_entity_tag::Has(_Proxy, n"TAG_MarsPlacedPickupDispatched"));
    }

    UFUNCTION()
    private void Step_DestroyPending(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_PendingChild.Is_WorldItem(), "child is genuinely under construction, before item/body composition");
        Assert_False(_PendingChild.Is_JoltBody(), "pending fixture has no body");
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 0, "no completed item exists yet");
        Assert_Equals_Int(utils_timer::ForEach_Timer(_Proxy, FInstancedStruct()).Num(), 0, "readiness timer already stopped");
        utils_entity_lifetime::Request_DestroyEntity(_Proxy);
        Destroy_Floors();
    }

    UFUNCTION()
    private void Check_PendingGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(ck::Is_NOT_Valid(_Proxy) && ck::Is_NOT_Valid(_PendingChild) && Get_SupportMask() == 0); }

    UFUNCTION()
    private void Step_AssertGone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(ck::IsValid(_WaitingProxy), "waiting owner ended");
        Assert_False(ck::IsValid(_WaitingTimer), "waiting timer ended");
        Assert_False(ck::IsValid(_PendingChild), "pending child ended");
        Assert_False(ck::IsValid(_Proxy), "pending owner ended");
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 0, "no late original item appeared");
    }
}
