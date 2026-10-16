// A carrier holding the yellow key at a Kept yellow lock reads Insert; inserting it moves the key out of the hotbar into
// the lock, with a key visual on the lock, and asserts the lock's source (Mechanism.Channel.Keys.Yellow). With the key in,
// the empty-handed carrier reads Blocked_KeyKept: a Kept lock never gives its key back. Isolated Z band: -91000.
class UMars_AutoTest_KeyLock_KeptKeyUnlocksForGood : UMars_AutoTestRig_KeyLock
{
    private FCk_Handle_KeyLock _Lock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, FVector(0.0, 0.0, -91000.0));
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(150.0, 0.0, -91000.0),
            GameplayTags::Key_Mars_Yellow, EMars_KeyLock_Release::Kept,
            GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Keys.Yellow")));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Yellow()));

        Add_Step_WaitUntil("the yellow key's holder is seeded", n"Check_HoldersSeeded");
        Add_Step("stow the key into the carrier's hotbar", n"Step_StowFirst");
        Add_Step_WaitUntil("the carrier holds the key", n"Check_KeyHeld");
        Add_Step("a locked lock offers Insert to a carrier holding its key", n"Step_AssertInsertOffered");
        Add_Step("insert the held key", n"Step_Insert");
        Add_Step_WaitUntil("the lock holds the key with a visual, the hotbar is empty and the source is asserted", n"Check_Unlocked");
        Add_Step_WaitUntil("the carrier's hands are empty", n"Check_HandsEmpty");
        Add_Step("a Kept lock offers nothing back", n"Step_AssertKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_KeyHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_AssertInsertOffered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Lock, "the yellow lock");
        Assert_False(_Lock.Get_IsUnlocked(), "the lock before the insert");
        Assert_False(Get_IsSourceAsserted(_Lock), "the lock's source before the insert");
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Insert, f"Get_ActionFor(carrier holding the yellow key) (got [{Action :n}])");
    }

    UFUNCTION()
    private void Step_Insert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lock.Request_Insert(FMars_Request_KeyLock_Insert(_Items[0]));
    }

    UFUNCTION()
    private void Check_Unlocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lock.Get_Key() == _Items[0] &&
                ck::IsValid(_Lock.Get_Visual()) &&
                ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)) &&
                Get_IsSourceAsserted(_Lock));
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Blocked_KeyKept, f"Get_ActionFor(empty-handed carrier) on a Kept lock (got [{Action :n}])");
    }
}
