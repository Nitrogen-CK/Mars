// An opt-in reading hold changes only the requested hold. Ordinary equipment keeps its authored geometry, and a
// caller cannot manufacture a held object by supplying an override with an invalid item.
class UMars_AutoTest_FPHands_HoldOverrideRequiresAnItemAndDefaultRestores : UMars_AutoTestRig_Hands
{
    private FCk_Handle_Inventory_DataOnly _Holder;
    private FCk_Handle_Item _Item;
    private FMars_FPHands_Hold _Default;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hands(InHandle, FMars_FPHands_Spec());
        _Holder = Add_SeededHolder(InHandle, mars_items::Rock());
        Add_Step_WaitUntil("the rock is seeded", n"Check_Seeded", 0, 0);
        Add_Step("equip normally", n"Step_Default");
        Add_Step_WaitFrames("the default request drains", 3);
        Add_Step("default geometry is unchanged, then request the opt-in hold", n"Step_Override");
        Add_Step_WaitFrames("the override request drains", 3);
        Add_Step("the override applied, then normal equipment restores geometry", n"Step_Restore");
        Add_Step_WaitFrames("the restore request drains", 3);
        Add_Step("default restored, then attempt an override without an item", n"Step_Invalid");
        Add_Step_WaitFrames("the invalid request drains", 3);
        Add_Step("an invalid item cannot forge a hold", n"Step_AssertInvalid");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Holder.Get_NumItems() == 1);
    }

    UFUNCTION()
    private void Step_Default(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _Holder.Get_Items()[0];
        _Default = utils_fphands::Make_Hold(_Item);
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_Item));
    }

    private void Assert_Default()
    {
        const auto Hold = _Hands.Get_Hold();
        Assert_True(Hold.Kind == _Default.Kind, "normal equipment preserves handedness");
        Assert_True(Hold.Bounds.HalfExtents.Equals(_Default.Bounds.HalfExtents, 0.001), "normal equipment uses authored bounds");
        Assert_True(Math::IsNearlyEqual(Hold.Faces.RightY, _Default.Faces.RightY, 0.001), "normal equipment uses authored side grip");
    }

    UFUNCTION()
    private void Step_Override(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Default();
        auto Override = _Default;
        Override.Faces.RightY = 91.0;
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_Item, Override));
    }

    UFUNCTION()
    private void Step_Restore(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Math::IsNearlyEqual(_Hands.Get_Hold().Faces.RightY, 91.0, 0.001), "a valid item accepts its explicit hold");
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_Item));
    }

    UFUNCTION()
    private void Step_Invalid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Default();
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(FCk_Handle_Item(), _Default));
    }

    UFUNCTION()
    private void Step_AssertInvalid(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Assert_True(_Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::Empty, "an override without a valid item leaves empty hands"); }
}
