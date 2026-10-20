// A Removable purple lock. Inserting the held key asserts its source (Mechanism.Channel.Keys.Purple). With the key in, an
// empty-handed carrier reads Take, and a carrier holding a rock reads Blocked_HandsFull. Once the carrier selects an empty
// slot, taking the key into the hotbar's take target puts it back in the carrier's hands, clears the lock's visual and
// deasserts the source. OnKeyChanged fires once per edge: naming the key on insert, naming no key on removal. The rig
// does not focus the lock, so its prompt is not read here. Isolated Z band: -93000.
class UMars_AutoTest_KeyLock_RemovableKeyRelocks : UMars_AutoTestRig_KeyLock
{
    private FCk_Handle_KeyLock _Lock;
    // Every OnKeyChanged, in order (invalid = emptied).
    private TArray<FCk_Handle_Item> _KeyChanges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, FVector(0.0, 0.0, -93000.0));
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);

        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(150.0, 0.0, -93000.0),
            GameplayTags::Key_Mars_Purple, EMars_KeyLock_Release::Removable,
            GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Keys.Purple")));
        _Lock.BindTo_OnKeyChanged(FMars_Delegate_KeyLock_OnKeyChanged(this, n"OnLockKeyChanged"));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Purple()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the purple key's and the rock's holders are seeded", n"Check_HoldersSeeded");
        Add_Step("stow the key into the carrier's hotbar", n"Step_StowFirst");
        Add_Step_WaitUntil("the carrier holds the key", n"Check_KeyHeld");
        Add_Step("insert the held key", n"Step_Insert");
        Add_Step_WaitUntil("the lock holds the key and its source is asserted", n"Check_Unlocked");
        Add_Step_WaitUntil("the carrier's hands are empty", n"Check_HandsEmpty");
        Add_Step("an empty-handed carrier reads Take; OnKeyChanged named the key once", n"Step_AssertTakeOffered");
        Add_Step("stow the rock into the selected empty slot", n"Step_StowSecond");
        Add_Step_WaitUntil("the carrier holds the rock", n"Check_RockHeld");
        Add_Step("a carrier holding a rock reads Blocked_HandsFull", n"Step_AssertHandsFull");
        Add_Step("select the empty second slot", n"Step_SelectEmptySlot");
        Add_Step_WaitUntil("the carrier's hands are empty", n"Check_HandsEmpty");
        Add_Step("remove the key into the take target", n"Step_Remove");
        Add_Step_WaitUntil("the carrier holds the key again, the lock and its visual are empty and its source is deasserted", n"Check_Relocked");
        Add_Step("OnKeyChanged fired once more, naming nothing", n"Step_AssertKeyEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnLockKeyChanged(FCk_Handle_KeyLock InLock, FCk_Handle_Item InMaybeKey)
    {
        _KeyChanges.Add(InMaybeKey);
    }

    UFUNCTION()
    private void Check_KeyHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_Insert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Lock, "the purple lock");
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Insert, f"Get_ActionFor(carrier holding the purple key) (got [{Action :n}])");
        _Lock.Request_Insert(FMars_Request_KeyLock_Insert(_Items[0]));
    }

    UFUNCTION()
    private void Check_Unlocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lock.Get_Key() == _Items[0] && Get_IsSourceAsserted(_Lock));
    }

    UFUNCTION()
    private void Step_AssertTakeOffered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Take, f"Get_ActionFor(empty-handed carrier) on a Removable lock with its key (got [{Action :n}])");
        Assert_Equals_Int(_KeyChanges.Num(), 1, "OnKeyChanged fired once for the insert");
        Assert_True(_KeyChanges[0] == _Items[0], "the insert's OnKeyChanged names the key");
    }

    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[1]);
    }

    UFUNCTION()
    private void Step_AssertHandsFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Blocked_HandsFull,
            f"Get_ActionFor(carrier holding a rock) on a Removable lock with its key (got [{Action :n}])");
        Assert_True(_Lock.Get_Key() == _Items[0], "the key is still in the lock");
    }

    UFUNCTION()
    private void Step_Remove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Take, f"Get_ActionFor(empty-handed carrier) after selecting the empty slot (got [{Action :n}])");

        auto Target = _Hotbar.TryGet_TakeTarget(_Items[0]);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("remove precondition: the key has a take target");
            return;
        }

        _Lock.Request_Take(FMars_Request_KeyLock_Take(_Items[0], Target));
    }

    UFUNCTION()
    private void Check_Relocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0] &&
                _Lock.Get_IsUnlocked() == false &&
                ck::Is_NOT_Valid(_Lock.Get_Visual()) &&
                Get_IsSourceAsserted(_Lock) == false);
    }

    UFUNCTION()
    private void Step_AssertKeyEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_KeyChanges.Num(), 2, "OnKeyChanged fired once per edge: insert, removal");
        Assert_True(ck::Is_NOT_Valid(_KeyChanges[1]), "the removal's OnKeyChanged names no key");
    }
}
