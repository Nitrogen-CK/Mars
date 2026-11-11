// A client's insert crosses as Cue.Mars.KeyLock.Act to the authority, whose drain moves the key out of the subject's
// slot into the lock; the lock's inventory replicates back, so on both machines the lock holds the key and the slot is
// empty. The server's source asserts; the client's copy shows the key in the keyhole and raised OnKeyChanged once, and the
// client saw no ensure.
// Surface: Ck.KeyLock.Net.AS_KeyLock_AClientInsertLandsTheKeyOnEveryMachine
class UCk_AutoTest_Net_KeyLock_AClientInsertLandsTheKeyOnEveryMachine : UMars_AutoTestRig_NetKeyLock
{
    private const FVector k_Base = FVector(36000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Compose_HotbarCarrier(k_Base + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_LockFoundAndKeyHeld", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLock(k_Base, EMars_KeyLock_Release::Kept);
        WaitUntil(n"Is_HotbarReady", n"OnServerHotbarReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHotbarReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Key_Red());
        WaitUntil(n"Is_LockFoundAndKeyHeld", n"OnServerSeeded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_InsertedAndAsserted", n"OnServerInserted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_InsertedAndAsserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Source = _Lock.As_MechanismSource(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(Get_IsInserted() && ck::IsValid(Source) && Source.Get_IsAsserted());
    }

    UFUNCTION()
    private void OnServerInserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Lock), "the client's lock has no authority");
        const auto Action = _Lock.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_KeyLock_Action::Insert, f"the client reads Insert while holding the red key (got [{Action :n}])");
        utils_key_lock::Request_ActFor(_Lock, Get_SubjectEntity(), EMars_KeyLock_Action::Insert);
        WaitUntil(n"Is_Inserted", n"OnClientContentsArrived", k_SlowPolls);
    }

    // The lock's sync reacts to the replicated contents on its next pass.
    UFUNCTION()
    private void OnClientContentsArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(5, n"OnClientInserted");
    }

    UFUNCTION()
    private void Is_Inserted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsInserted());
    }

    UFUNCTION()
    private void OnClientInserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasVisual = ck::IsValid(_Lock.Get_Visual());
        const auto NewEnsures = Get_NewEnsures();
        Assert_True(HasVisual, "the client's lock shows the key in the keyhole");
        Assert_True(_KeyChanges == 1, f"the client's lock raised OnKeyChanged once (got {_KeyChanges})");
        Assert_True(NewEnsures == 0, f"the client saw no ensure (got {NewEnsures})");
        Log(f"[KeyLockNetTest] client insert landed visual={HasVisual} keyChanges={_KeyChanges} newEnsures={NewEnsures}");
        FinishSuccess();
    }

    private bool Get_IsInserted()
    {
        return ck::IsValid(_Lock) && ck::IsValid(_Key) && _Lock.Get_Key() == _Key && Get_SlotItemCount(0) == 0;
    }
}
