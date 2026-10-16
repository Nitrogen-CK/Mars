// A red lock reads Blocked_NothingHeld for an empty-handed carrier and Blocked_WrongKey for one holding the blue key, and
// its inventory's accept policy agrees: it would take the red key and not the blue one. The lock stays locked. Isolated Z
// band: -92000.
class UMars_AutoTest_KeyLock_WrongKeyIsBlocked : UMars_AutoTestRig_KeyLock
{
    private FCk_Handle_KeyLock _Lock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, FVector(0.0, 0.0, -92000.0));
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(150.0, 0.0, -92000.0),
            GameplayTags::Key_Mars_Red, EMars_KeyLock_Release::Kept, FGameplayTag()));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Blue()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Red()));

        Add_Step_WaitUntil("both key holders are seeded", n"Check_HoldersSeeded");
        Add_Step("an empty-handed carrier reads Blocked_NothingHeld", n"Step_AssertNothingHeld");
        Add_Step("stow the blue key into the carrier's hotbar", n"Step_StowFirst");
        Add_Step_WaitUntil("the carrier holds the blue key", n"Check_BlueHeld");
        Add_Step("the red lock refuses the blue key", n"Step_AssertWrongKey");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertNothingHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Lock, "the red lock");
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Blocked_NothingHeld, f"Get_ActionFor(empty-handed carrier) (got [{Action :n}])");
    }

    UFUNCTION()
    private void Check_BlueHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_AssertWrongKey(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Blocked_WrongKey, f"Get_ActionFor(carrier holding the blue key) (got [{Action :n}])");

        Assert_False(_Lock.Get_Accepts(_Items[0]), "the red lock accepts the blue key");
        Assert_True(_Lock.Get_Accepts(_Items[1]), "the red lock accepts the red key");
        const auto RedResult = utils_inventory::Get_CanAcceptItem(_Lock.Get_Inventory(), _Items[1]);
        Assert_True(RedResult == ECk_Inventory_OperationResult_Add::Success, f"the lock's inventory would take the red key (got [{RedResult :n}])");
        const auto BlueResult = utils_inventory::Get_CanAcceptItem(_Lock.Get_Inventory(), _Items[0]);
        Assert_True(BlueResult != ECk_Inventory_OperationResult_Add::Success, "the lock's inventory refuses the blue key");
        Assert_False(_Lock.Get_IsUnlocked(), "the red lock after the refusals");
    }
}
