// A carrier holding an open lantern lights its Held pool; hanging it moves the lantern's one body onto the hook (Carried by
// the hook entity, settled), where it lights its World pool - the radius and the Probe.Mars.Light probe both follow - and
// leaves the carrier's hands empty; an empty-handed carrier then reads Take, and taking it puts it back in the carrier's
// hand at its Held pool. Isolated Z band: -97000.
class UMars_AutoTest_LanternHook_HangsAHeldLanternAndLightsItsWorldPool : UMars_AutoTestRig_LanternHook
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBelt(InHandle, FVector(0.0, 0.0, -97000.0));
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        _Hook = MakeHook(InHandle, FVector(150.0, 0.0, -97000.0), FGameplayTag());
        SpawnLantern(InHandle, mars_items::Lantern(), FVector(0.0, 150.0, -97000.0));

        Add_Step_WaitUntil("the lantern world item is composed", n"Check_LanternReady", k_SlowPolls, 0);
        Add_Step("stow the lantern into the carrier's hotbar", n"Step_StowLantern");
        Add_Step("open its shutter", n"Step_OpenShutter");
        Add_Step_WaitUntil("the carrier holds the lit lantern at its Held pool", n"Check_LanternHeldAndLit", k_SlowPolls, 0);
        Add_Step_WaitUntil("only the Held light probe is enabled", n"Check_HeldProbeEnabled", k_SlowPolls, 0);
        Add_Step("the Held pool lights the Held radius", n"Step_AssertHeldPool");
        Add_Step("hang the held lantern", n"Step_Hang");
        Add_Step_WaitUntil("the lantern hangs on the hook, settled", n"Check_Hung", k_SlowPolls, 0);
        Add_Step_WaitUntil("only the World light probe is enabled", n"Check_WorldProbeEnabled", k_SlowPolls, 0);
        Add_Step("a hung lantern lights its World pool and the carrier's hands are empty", n"Step_AssertWorldPool");
        Add_Step("take it back", n"Step_Take");
        Add_Step_WaitUntil("the carrier holds the lit lantern at its Held pool again", n"Check_LanternHeldAndLit", k_SlowPolls, 0);
        Add_Step("the hook is empty", n"Step_AssertHookEmpty");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_HeldProbeEnabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_OnlyEnabled(EMars_Lantern_Pool::Held));
    }

    UFUNCTION()
    private void Check_WorldProbeEnabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_OnlyEnabled(EMars_Lantern_Pool::World));
    }

    UFUNCTION()
    private void Step_AssertHeldPool(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lantern = Get_Lantern();
        Assert_True(Lantern.Get_LightPool() == EMars_Lantern_Pool::Held, f"a lantern in the hand lights its Held pool (got [{Lantern.Get_LightPool() :n}])");
        Assert_Equals_Float(Lantern.Get_LightRadius(), FMars_Lantern_Radius().Held, 0.01f, "the Held radius");
        Assert_True(utils_lantern_hook::Get_IsLantern(Get_LanternItem()), "the hook's accept rule takes a lantern");
    }

    UFUNCTION()
    private void Step_AssertWorldPool(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lantern = Get_Lantern();
        const FCk_Handle HookEntity = _Hook;
        Assert_True(_LanternItem.Get_Carrier() == HookEntity, "the hung lantern is Carried by the hook entity");
        Assert_True(Lantern.Get_LightPool() == EMars_Lantern_Pool::World, f"a hung lantern lights its World pool (got [{Lantern.Get_LightPool() :n}])");
        Assert_Equals_Float(Lantern.Get_LightRadius(), FMars_Lantern_Radius().World, 0.01f, "the World radius");
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the carrier's hands are empty");
        Assert_True(_Hook.Get_HoldsLitLantern(), "the hook holds a lit lantern");

        const auto Action = _Hook.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_LanternHook_Action::Take, f"an empty-handed carrier reads Take on a hung lantern (got [{Action :n}])");
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Item = Get_LanternItem();
        auto Target = _Hotbar.TryGet_TakeTarget(Item);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("take precondition: the hung lantern has a take target");
            return;
        }

        _Hook.Request_Take(FMars_Request_LanternHook_Take(Item, Target));
    }

    UFUNCTION()
    private void Step_AssertHookEmpty(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hook.Get_IsOccupied(), "the hook is empty once its lantern is taken");
    }

    // InPool's probe is the shown one and the only enabled one.
    private bool Get_OnlyEnabled(EMars_Lantern_Pool InPool) const
    {
        const auto Lantern = Get_Lantern();
        const auto Shown = Lantern.Get_ShownLightPool();
        if (Shown.IsSet() == false || Shown.GetValue() != InPool)
        { return false; }

        auto Pools = TArray<EMars_Lantern_Pool>();
        Pools.Add(EMars_Lantern_Pool::Held);
        Pools.Add(EMars_Lantern_Pool::World);
        for (const auto Pool : Pools)
        {
            const auto Probe = Lantern.Get_LightProbe(Pool);
            if (ck::Is_NOT_Valid(Probe))
            { return false; }

            const auto Want = Pool == InPool ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
            if (utils_probe::Get_IsEnabledDisabled(Probe) != Want)
            { return false; }
        }

        return true;
    }
}
