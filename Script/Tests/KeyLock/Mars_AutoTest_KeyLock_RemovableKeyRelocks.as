// A Removable purple lock: inserting the held key asserts its source (Mechanism.Channel.Keys.Purple); with the key in, an
// empty-handed carrier reads Remove and a full-handed one would read Blocked_HandsFull; removing it into the hotbar's take
// target puts the key back in the carrier's hands, clears the lock's visual and deasserts the source. Isolated Z band:
// -93000.
class UMars_AutoTest_KeyLock_RemovableKeyRelocks : UMars_AutoTestRig_KeyLock
{
    private FCk_Handle_KeyLock _Lock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, FVector(0.0, 0.0, -93000.0));
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(150.0, 0.0, -93000.0),
            GameplayTags::Key_Mars_Purple, EMars_KeyLock_Release::Removable,
            GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Keys.Purple")));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Purple()));

        Add_Step_WaitUntil("the purple key's holder is seeded", n"Check_HoldersSeeded");
        Add_Step("stow the key into the carrier's hotbar", n"Step_StowFirst");
        Add_Step_WaitUntil("the carrier holds the key", n"Check_KeyHeld");
        Add_Step("insert the held key", n"Step_Insert");
        Add_Step_WaitUntil("the lock holds the key and its source is asserted", n"Check_Unlocked");
        Add_Step_WaitUntil("the carrier's hands are empty", n"Check_HandsEmpty");
        Add_Step("an empty-handed carrier reads Remove", n"Step_AssertRemoveOffered");
        Add_Step("remove the key into the take target", n"Step_Remove");
        Add_Step_WaitUntil("the carrier holds the key again, the lock and its visual are empty and its source is deasserted", n"Check_Relocked");
        Run_Steps(InHandle);
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
    private void Step_AssertRemoveOffered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_KeyLock_Action::Take, f"Get_ActionFor(empty-handed carrier) on a Removable lock with its key (got [{Action :n}])");
    }

    UFUNCTION()
    private void Step_Remove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
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
}
