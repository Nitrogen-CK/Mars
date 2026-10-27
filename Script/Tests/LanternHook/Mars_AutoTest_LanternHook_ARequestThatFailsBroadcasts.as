// A holder accept policy that refuses every item, so any transfer into it fails.
class UMars_AutoTestHelper_LanternHook_RefusingTarget : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = false; }
}

// A take whose target refuses the lantern fails, and the hook reports it once. A lantern is hung from its own world item's
// holder onto an empty hook (no source), and OnLanternChanged fires once, naming it. The lantern is then taken toward a
// holder whose accept policy refuses everything. CkInventory rolls the transfer back. The hook's request processor
// ensures and broadcasts OnRequestFailed exactly once, from the hook, naming the lantern. The lantern stays hung and
// settled on the hook, the refusing holder stays empty and OnLanternChanged does not fire again. The actor below expects
// the rollback's warning and requires the ensure. Isolated Z band: -96000.
class UMars_AutoTest_LanternHook_ARequestThatFailsBroadcasts : UMars_AutoTestRig_LanternHook
{
    private FCk_Handle_Inventory_DataOnly _RefusingHolder;
    // Every OnLanternChanged, in order (invalid = emptied).
    private TArray<FCk_Handle_Item> _LanternChanges;
    // Every OnRequestFailed, in order: the hook that reported it and the item it names.
    private TArray<FCk_Handle_LanternHook> _FailedHooks;
    private TArray<FCk_Handle_Item> _FailedItems;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Hook = MakeHook(InHandle, FVector(150.0, 0.0, -96000.0), FGameplayTag());
        _Hook.BindTo_OnLanternChanged(FMars_Delegate_LanternHook_OnLanternChanged(this, n"OnHookLanternChanged"));
        _Hook.BindTo_OnRequestFailed(FMars_Delegate_LanternHook_OnRequestFailed(this, n"OnHookRequestFailed"));

        SpawnLantern(InHandle, mars_items::Lantern(), FVector(0.0, 150.0, -96000.0));
        _RefusingHolder = MakeRefusingHolder(InHandle);

        Add_Step_WaitUntil("the lantern world item is composed", n"Check_FlameReady", k_SlowPolls, 0);
        Add_Step("hang the lantern from its world item's holder", n"Step_HangFromHolder");
        Add_Step_WaitUntil("the lantern hangs on the hook, settled", n"Check_Hung", k_SlowPolls, 0);
        Add_Step("the hook announced the lantern once; take it toward the refusing holder", n"Step_AssertHungAndTake");
        Add_Step_WaitUntil("the hook reported the failed request", n"Check_RequestFailed", k_SlowPolls, 0);
        Add_Step("one failure naming the lantern, and nothing moved", n"Step_AssertNothingMoved");
        Run_Steps(InHandle);
    }

    private FCk_Handle_Inventory_DataOnly MakeRefusingHolder(FCk_Handle InHandle)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        TSubclassOf<UMars_AutoTestHelper_LanternHook_RefusingTarget> PolicyClass = UMars_AutoTestHelper_LanternHook_RefusingTarget;
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(PolicyClass.GetDefaultObject(), n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        return utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);
    }

    UFUNCTION()
    private void OnHookLanternChanged(FCk_Handle_LanternHook InHook, FCk_Handle_Item InMaybeLantern)
    {
        _LanternChanges.Add(InMaybeLantern);
    }

    UFUNCTION()
    private void OnHookRequestFailed(FCk_Handle_LanternHook InHook, FCk_Handle_Item InItem)
    {
        _FailedHooks.Add(InHook);
        _FailedItems.Add(InItem);
    }

    UFUNCTION()
    private void Step_HangFromHolder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Hook, "the hook");
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(Get_FlameItem()));
    }

    UFUNCTION()
    private void Step_AssertHungAndTake(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_LanternChanges.Num(), 1, "OnLanternChanged fired once for the hang");
        Assert_True(_LanternChanges[0] == Get_FlameItem(), "the hang's OnLanternChanged names the lantern");
        Assert_Equals_Int(_FailedItems.Num(), 0, "no request failed while hanging");

        _Hook.Request_Take(FMars_Request_LanternHook_Take(Get_FlameItem(), _RefusingHolder));
    }

    UFUNCTION()
    private void Check_RequestFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedItems.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertNothingMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FailedItems.Num(), 1, "OnRequestFailed fired once");
        Assert_True(_FailedHooks[0] == _Hook, "the hook reported the failure");
        Assert_True(_FailedItems[0] == Get_FlameItem(), "the failure names the lantern");
        Assert_True(_Hook.Get_Item() == Get_FlameItem(), "the lantern still hangs on the hook");
        Assert_True(_Hook.Get_HasArrived(), "the lantern is still Carried by the hook and settled");
        Assert_Equals_Int(_RefusingHolder.Get_NumItems(), 0, "the refusing holder stayed empty");
        Assert_Equals_Int(_LanternChanges.Num(), 1, "OnLanternChanged did not fire again");
    }
}

// Hand-authored so CkInventory's rollback warning for the refused take is expected and the hook's ensure is required
// exactly once. The warning is pinned to the item definition and the refusal reason; the ensure to the refusing target
// and the transfer result.
class AMars_AutoTest_LanternHook_ARequestThatFailsBroadcasts_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_LanternHook_ARequestThatFailsBroadcasts;
    default _TimeoutSeconds = 30.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Item (Mars_ItemDef_Lantern))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Inventory.Mars.WorldItemHolder)] failed with [Failed_RejectedByCustomAcceptanceLogic]");
        return Out;
    }
}
