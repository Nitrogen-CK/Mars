// A source hook (Mechanism.Channel.LanternHook.Test) takes only lanterns: a carrier holding tallow reads Blocked_NotALantern
// on it while it is empty. A hung lit lantern asserts the hook's source; snuffing it deasserts the source and lighting it
// again re-asserts it; a snuffed lantern shows no light probe. A carrier holding tallow then reads Refuel on the low hung
// lantern, and the refuel feeds it the tallow's two measures and uses the tallow up. Isolated Z band: -98000.
class UMars_AutoTest_LanternHook_ALitLanternAssertsItsSourceAndTakesTallow : UMars_AutoTestRig_LanternHook
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBelt(InHandle, FVector(0.0, 0.0, -98000.0));
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);

        _Hook = MakeHook(InHandle, FVector(150.0, 0.0, -98000.0), GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.LanternHook.Test"));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Tallow()));
        SpawnLantern(InHandle, mars_test_items::LowLantern(), FVector(0.0, 150.0, -98000.0));

        Add_Step_WaitUntil("the tallow's holder is seeded and the lantern composed", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("stow the tallow into the carrier's hotbar", n"Step_StowFirst");
        Add_Step_WaitUntil("the carrier holds the tallow", n"Check_HoldsTallow", k_SlowPolls, 0);
        Add_Step("an empty hook refuses the tallow", n"Step_AssertNotALantern");
        Add_Step("stow the lantern into the second slot", n"Step_StowFlame");
        Add_Step_WaitUntil("the second slot holds the lantern", n"Check_SecondStowed", k_SlowPolls, 0);
        Add_Step("select the lantern and light it", n"Step_SelectLanternAndLight");
        Add_Step_WaitUntil("the carrier holds the lit lantern at its Held pool", n"Check_FlameHeldAndLit", k_SlowPolls, 0);
        Add_Step("the source is down while the lantern is in the hand", n"Step_AssertDeasserted");
        Add_Step("hang the held lantern", n"Step_Hang");
        Add_Step_WaitUntil("the lantern hangs on the hook, settled", n"Check_Hung", k_SlowPolls, 0);
        Add_Step_WaitUntil("the hook's source is asserted", n"Check_Asserted", k_SlowPolls, 0);
        Add_Step("snuff the hung lantern", n"Step_Snuff");
        Add_Step_WaitUntil("the hook's source is deasserted", n"Check_Deasserted", k_SlowPolls, 0);
        Add_Step("light it again", n"Step_Light");
        Add_Step_WaitUntil("the hook's source is asserted again", n"Check_Asserted", k_SlowPolls, 0);
        Add_Step("select the tallow", n"Step_SelectZero");
        Add_Step_WaitUntil("the carrier holds the tallow", n"Check_HoldsTallow", k_SlowPolls, 0);
        Add_Step("a carrier holding tallow reads Refuel; refuel the hung lantern", n"Step_Refuel");
        Add_Step_WaitUntil("the lantern has three measures and the tallow is gone", n"Check_Refuelled", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Seeded = _Holders[0].Get_NumItems() == 1;
        if (Seeded && _Items.Num() == 0)
        { _Items.Add(_Holders[0].Get_Items()[0]); }

        const auto Composed = Get_IsFlameReady();
        auto Res = OutResult;
        Res.Set(Seeded && Composed);
    }

    UFUNCTION()
    private void Check_HoldsTallow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_AssertNotALantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_lantern_hook::Get_IsLantern(_Items[0]), "the hook's accept rule refuses tallow");
        const auto Action = _Hook.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_LanternHook_Action::Blocked_NotALantern, f"tallow on an empty hook reads Blocked_NotALantern (got [{Action :n}])");
    }

    UFUNCTION()
    private void Step_SelectLanternAndLight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
        Step_Light(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_AssertDeasserted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(Get_IsSourceAsserted(_Hook), "an empty hook's source is down");
    }

    UFUNCTION()
    private void Check_Asserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSourceAsserted(_Hook));
    }

    UFUNCTION()
    private void Check_Deasserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSourceAsserted(_Hook) == false && Get_Flame().Get_IsLit() == false
            && Get_Flame().Get_ShownLightPool().IsSet() == false);
    }

    UFUNCTION()
    private void Step_Refuel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_Flame().Get_MeasuresLeft(), 1, "the low lantern has one measure");
        const auto Action = _Hook.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_LanternHook_Action::Refuel, f"tallow on a low hung lantern reads Refuel (got [{Action :n}])");
        _Hook.Request_Refuel(FMars_Request_LanternHook_Refuel(_Items[0]));
    }

    UFUNCTION()
    private void Check_Refuelled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Flame().Get_MeasuresLeft() == 3 && ck::Is_NOT_Valid(_Items[0]) && _Hotbar.Get_Slot(0).Get_NumItems() == 0);
    }
}
