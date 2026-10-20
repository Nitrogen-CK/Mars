// The focus lean is re-resolved when the hold changes: with empty hands the right glove leans at a focused interactable;
// equipping a one-handed item (the right glove now carries it) moves the lean to the free left glove, the right glove's
// lean easing out rather than staying on the target it no longer reaches for.
class UMars_AutoTest_FPHands_EquippingReResolvesTheFocusLean : UMars_AutoTestRig_Hands
{
    private FCk_Handle _Owner;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_Inventory_DataOnly _Holder;
    private float32 _LastRight = 0.0f;
    private int32 _EasingFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hands(InHandle, FMars_FPHands_Spec());
        _Interactable = Add_PlainInteractable(InHandle, FVector(80.0, 20.0, 0.0), _Owner);
        _Holder = Add_SeededHolder(InHandle, mars_items::Key_Red());

        Add_Step_WaitUntil("the holder holds the key", n"Check_Seeded", 0, 0);
        Add_Step("focus the interactable with empty hands", n"Step_Focus");
        Add_Step_WaitUntil("the right glove leans in", n"Check_RightLeanedIn", k_SlowPolls, 0);
        Add_Step("equip the one-handed key", n"Step_Equip");
        Add_Step_WaitUntil("the left glove leans in and the right glove's lean is gone", n"Check_LeanMovedLeft", k_SlowPolls, 0);
        Add_Step("the lean moved to the free glove, the busy one eased out", n"Step_AssertMoved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Holder.Get_NumItems() == 1);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus(_Interactable, _Owner));
    }

    UFUNCTION()
    private void Check_RightLeanedIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AppliedLean(EMars_Hand::Right) > _Hands.Get_Spec().Reach.Focus.Lean * 0.9f
            && Get_AppliedLean(EMars_Hand::Left) < 0.001f);
    }

    UFUNCTION()
    private void Step_Equip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LastRight = Get_AppliedLean(EMars_Hand::Right);
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_Holder.Get_Items()[0]));
    }

    UFUNCTION()
    private void Check_LeanMovedLeft(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Right = Get_AppliedLean(EMars_Hand::Right);
        if (Right > 0.001f && Right < _LastRight - 0.0001f)
        { _EasingFrames += 1; }

        _LastRight = Right;
        Res.Set(_Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::OneHanded
            && Get_AppliedLean(EMars_Hand::Left) > _Hands.Get_Spec().Reach.Focus.Lean * 0.9f && Right < 0.001f);
    }

    UFUNCTION()
    private void Step_AssertMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Hands.Get_FocusTarget();
        Assert_True(utils_fphands::Get_UsesHand(Target, EMars_Hand::Left), "the focus target now uses the free left glove");
        Assert_False(utils_fphands::Get_UsesHand(Target, EMars_Hand::Right), "the focus target no longer uses the busy right glove");
        Assert_True(_EasingFrames >= 2, f"the right glove's lean eased out over [{_EasingFrames}] frames (at least 2)");
    }
}
