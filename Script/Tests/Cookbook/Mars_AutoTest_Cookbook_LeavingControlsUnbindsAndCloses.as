// Exiting the player's free-roam control scope closes the book and removes every intent/held-item/launch listener.
class UMars_AutoTest_Cookbook_LeavingControlsUnbindsAndCloses : UMars_AutoTestRig_Cookbook
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Cookbook(InHandle, FVector(131000.0, -49000.0, -30000.0));
        Add_Steps_PickupAndOpen();
        Add_Step("stop the free-roam task scope", n"Step_StopControls");
        Add_Step_WaitUntil("the book closed on scope exit", n"Check_BookClosed", 0, 0);
        Add_Step_WaitFrames("all task exits and unbinds settle", 4);
        Add_Step("the controls released their signal subscriptions", n"Step_AssertUnboundAndPress");
        Add_Step_WaitFrames("keys with the controls gone do nothing", 8);
        Add_Step("the book stayed closed; destroy its item", n"Step_AssertClosedAndDestroy");
        Add_Step_WaitUntil("the persistent world book ends with its item", n"Check_Destroyed", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_StopControls(FCk_Handle InHandle, FInstancedStruct InPayload)
    { utils_state_machine::Request_Stop(_Sm); }

    UFUNCTION()
    private void Step_AssertUnboundAndPress(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_HeldItem.Get_Fragment(FMars_Fragment_HeldItem_Signals).OnHeldItemChanged._Inner.IsBound(),
            "scope exit unbinds held-item listeners");
        Assert_False(_BookUse.Get_Fragment(FMars_Fragment_HeldItemUse_Signals).OnItemLaunched._Inner.IsBound(),
            "scope exit unbinds the cookbook launch listener");
        Assert_False(_Intents.Get_Fragment(FMars_Fragment_InputIntents_Signals).OnMatcherChanged._Inner.IsBound(),
            "scope exit unbinds all intent readers from matcher changes");
        Step_TapPrimary(InHandle, InPayload);
        _UseKey.Press_Row(utils_cookbook::Get_NextIntent());
        _UseKey.Release_Row(utils_cookbook::Get_NextIntent());
    }

    UFUNCTION()
    private void Step_AssertClosedAndDestroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_BookPresentation.Get_IsOpen(), "keys cannot reopen the book after the control scope ends");
        Assert_Equals_Int(_BookPresentation.Get_PageSectionIndex(), 0, "keys cannot turn pages after the control scope ends");
        auto Inventory = _BookItem.Get_ParentInventory();
        auto Remove = FCk_Request_Inventory_RemoveItem(_BookItem);
        Remove.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Inventory.Request_RemoveItem(Remove, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    UFUNCTION()
    private void Check_Destroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_WorldBook) && ck::Is_NOT_Valid(_BookItem));
    }
}
