// A holder accept policy that refuses every item, so any transfer into it fails.
class UMars_AutoTestHelper_KeyLock_RefusingTarget : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = false; }
}

// A take whose target refuses the key fails, and the lock reports it once. The purple key is inserted from its holder
// into a Removable purple lock, and OnKeyChanged fires once, naming it. The key is then taken toward a holder whose accept
// policy refuses everything. CkInventory rolls the transfer back. The lock's request processor ensures and broadcasts
// OnTransferFailed exactly once, from the lock, naming the key. The key stays in the lock with its visual, the refusing
// holder stays empty and OnKeyChanged does not fire again. The actor below expects the rollback's warning and requires
// the ensure. Isolated Z band: -95000.
class UMars_AutoTest_KeyLock_ATransferThatFailsBroadcasts : UMars_AutoTestRig_KeyLock
{
    private FCk_Handle_KeyLock _Lock;
    private FCk_Handle_Inventory_DataOnly _RefusingHolder;
    // Every OnKeyChanged, in order (invalid = emptied).
    private TArray<FCk_Handle_Item> _KeyChanges;
    // Every OnTransferFailed, in order: the lock that reported it and the item it names.
    private TArray<FCk_Handle_KeyLock> _FailedLocks;
    private TArray<FCk_Handle_Item> _FailedItems;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(150.0, 0.0, -95000.0),
            GameplayTags::Key_Mars_Purple, EMars_KeyLock_Release::Removable, FGameplayTag()));
        _Lock.BindTo_OnKeyChanged(FMars_Delegate_KeyLock_OnKeyChanged(this, n"OnLockKeyChanged"));
        _Lock.BindTo_OnTransferFailed(FMars_Delegate_KeyLock_OnTransferFailed(this, n"OnLockTransferFailed"));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Purple()));
        _RefusingHolder = MakeRefusingHolder(InHandle);

        Add_Step_WaitUntil("the purple key's holder is seeded", n"Check_HoldersSeeded");
        Add_Step("insert the key from its holder", n"Step_Insert");
        Add_Step_WaitUntil("the lock holds the key and shows its visual", n"Check_Inserted");
        Add_Step("the lock announced the key once; take it toward the refusing holder", n"Step_AssertInsertedAndTake");
        Add_Step_WaitUntil("the lock reported the failed transfer", n"Check_TransferFailed");
        Add_Step("one failure naming the key, and nothing moved", n"Step_AssertNothingMoved");
        Run_Steps(InHandle);
    }

    private FCk_Handle_Inventory_DataOnly MakeRefusingHolder(FCk_Handle InHandle)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        TSubclassOf<UMars_AutoTestHelper_KeyLock_RefusingTarget> PolicyClass = UMars_AutoTestHelper_KeyLock_RefusingTarget;
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(PolicyClass.GetDefaultObject(), n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        return utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);
    }

    UFUNCTION()
    private void OnLockKeyChanged(FCk_Handle_KeyLock InLock, FCk_Handle_Item InMaybeKey)
    {
        _KeyChanges.Add(InMaybeKey);
    }

    UFUNCTION()
    private void OnLockTransferFailed(FCk_Handle_KeyLock InLock, FCk_Handle_Item InItem)
    {
        _FailedLocks.Add(InLock);
        _FailedItems.Add(InItem);
    }

    UFUNCTION()
    private void Step_Insert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Lock, "the purple lock");
        _Lock.Request_Insert(FMars_Request_KeyLock_Insert(_Items[0]));
    }

    UFUNCTION()
    private void Check_Inserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lock.Get_Key() == _Items[0] && ck::IsValid(_Lock.Get_Visual()) && _KeyChanges.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertInsertedAndTake(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_KeyChanges.Num(), 1, "OnKeyChanged fired once for the insert");
        Assert_True(_KeyChanges[0] == _Items[0], "the insert's OnKeyChanged names the key");
        Assert_Equals_Int(_Holders[0].Get_NumItems(), 0, "the key's holder emptied into the lock");
        Assert_Equals_Int(_FailedItems.Num(), 0, "no transfer failed while inserting");

        _Lock.Request_Take(FMars_Request_KeyLock_Take(_Items[0], _RefusingHolder));
    }

    UFUNCTION()
    private void Check_TransferFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedItems.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertNothingMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FailedItems.Num(), 1, "OnTransferFailed fired once");
        Assert_True(_FailedLocks[0] == _Lock, "the lock reported the failure");
        Assert_True(_FailedItems[0] == _Items[0], "the failure names the key");
        Assert_True(_Lock.Get_Key() == _Items[0], "the key is still in the lock");
        Assert_True(ck::IsValid(_Lock.Get_Visual()), "the lock still shows the key's visual");
        Assert_Equals_Int(_RefusingHolder.Get_NumItems(), 0, "the refusing holder stayed empty");
        Assert_Equals_Int(_KeyChanges.Num(), 1, "OnKeyChanged did not fire again");
    }
}

// Hand-authored so CkInventory's rollback warning for the refused take is expected and the lock's ensure is required
// exactly once. The warning is pinned to the item definition and the refusal reason; the ensure to the refusing target
// and the transfer result.
class AMars_AutoTest_KeyLock_ATransferThatFailsBroadcasts_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_KeyLock_ATransferThatFailsBroadcasts;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Item (Mars_ItemDef_Key_Purple))] (Failed Rejected by Custom Acceptance Logic)");
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
