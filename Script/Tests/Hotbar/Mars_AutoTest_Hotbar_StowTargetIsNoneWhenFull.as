// Once both bag slots and the overflow slot hold an item there is nowhere to stow: the pickup target goes silent.
class UMars_AutoTest_Hotbar_StowTargetIsNoneWhenFull : UMars_AutoTestRig_Carrier
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);

        for (int32 Index = 0; Index < 3; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock())); }

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the first rock", n"Step_StowFirst");
        Add_Step_WaitUntil("slot 0 holds it", n"Check_FirstStowed");
        Add_Step("stow the second rock", n"Step_StowSecond");
        Add_Step_WaitUntil("slot 1 holds it", n"Check_SecondStowed");
        Add_Step("stow the third rock", n"Step_StowThird");
        Add_Step_WaitUntil("the overflow slot holds it and is selected", n"Check_OverflowFilled");
        Add_Step("no stow target remains", n"Step_AssertNoStowTarget");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_FirstStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)));
    }

    UFUNCTION()
    private void Step_AssertNoStowTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Any non-backpack item asks the same question; the stowed rock in slot 0 is one at hand.
        const auto Rock = _Hotbar.Get_ItemAt(0);
        Assert_Invalid(_Hotbar.TryGet_StowTarget(Rock), "a rock has no stow target with every slot full");
        Assert_False(_Hotbar.Get_CanStow(Rock), "Get_CanStow(rock) is false with every slot full");
    }
}
