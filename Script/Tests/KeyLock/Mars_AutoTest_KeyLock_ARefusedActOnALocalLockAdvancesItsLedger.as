// A lock composed on a host with no replication driver (a rig's, as here) takes an Act directly, and refuses it the way a
// replicated lock does: an empty-handed carrier asking an empty lock for Take is refused ActionBlocked, the lock's ledger
// advances once naming the carrier, and nothing ensures. Isolated Z band: -99500.
class UMars_AutoTest_KeyLock_ARefusedActOnALocalLockAdvancesItsLedger : UMars_AutoTestRig_KeyLock
{
    private FCk_Handle_KeyLock _Lock;
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, FVector(0.0, 0.0, -99500.0));
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(FVector(150.0, 0.0, -99500.0),
            GameplayTags::Key_Mars_Yellow, EMars_KeyLock_Release::Kept, FGameplayTag()));

        Add_Step("ask the empty lock for a Take with empty hands", n"Step_AskForATake");
        Add_Step_WaitUntil("the lock's ledger records the refusal", n"Check_Refused");
        Add_Step("the refusal names the carrier and nothing ensured", n"Step_AssertRefusal");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AskForATake(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Lock, "the lock");
        const auto Action = _Lock.Get_ActionFor(_Carrier);
        Assert_True(Action != EMars_KeyLock_Action::Take, f"an empty lock offers no Take (got [{Action :n}])");
        Assert_True(_Lock.Get_RefusalSerial() == 0, "the ledger starts with no refusal");

        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        utils_key_lock::Request_ActFor(_Lock, _Carrier, EMars_KeyLock_Action::Take);
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lock.Get_RefusalSerial() == 1);
    }

    UFUNCTION()
    private void Step_AssertRefusal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lock.Get_LastRefusal() == EMars_Interaction_FailReason::ActionBlocked,
            f"the refusal's reason (got [{_Lock.Get_LastRefusal() :n}])");
        Assert_True(_Lock.Get_LastRefused() == _Carrier, "the refusal names the carrier");
        Assert_False(_Lock.Get_IsUnlocked(), "the lock is still empty");
        const auto NewEnsures = utils_ensure::Get_EnsureCount() - _EnsuresBefore;
        Assert_True(NewEnsures == 0, f"no ensure fired while the lock refused (got [{NewEnsures}])");
    }
}
