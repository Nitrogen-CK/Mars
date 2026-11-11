// The key-lock net tests' shared steps, on top of the net hotbar rig: the server spawns a red UMars_KeyLock_EntityScript
// (asserting Mechanism.Channel.A) under the replicated spawn owner and seeds a red key into the subject's slot 0; each
// machine finds its copy of the lock by tag and counts the OnKeyChanged its own copy raises.
UCLASS(Abstract)
class UMars_AutoTestRig_NetKeyLock : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 20.0f;

    protected const float32 k_SettleSeconds = 1.5f;

    protected FCk_Handle_KeyLock _Lock;
    // The key as this machine knows it: the one in slot 0 or in the lock.
    protected FCk_Handle_Item _Key;
    protected int32 _KeyChanges = 0;
    protected int32 _EnsuresAtStart = 0;

    // Server: the lock at InLocation, released per InRelease.
    protected void Spawn_ServerLock(FVector InLocation, EMars_KeyLock_Release InRelease)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_KeyLock_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        Params.AcceptedKey = GameplayTags::Key_Mars_Red;
        Params.Release = InRelease;
        Params.Source.OutputChannel = GameplayTags::Mechanism_Channel_A;
        utils_entity_script::Request_SpawnEntity(Owner, UMars_KeyLock_EntityScript, Params);
    }

    // This machine's lock has composed; the first time, its OnKeyChanged is counted from here (and the server tracks it).
    protected bool Get_IsLockFound()
    {
        if (ck::IsValid(_Lock))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsKeyLock"))
        {
            auto Lock = Candidate.As_KeyLock(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Lock))
            { continue; }

            _Lock = Lock;
            _Lock.BindTo_OnKeyChanged(FMars_Delegate_KeyLock_OnKeyChanged(this, n"OnLockKeyChanged"));
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    UFUNCTION()
    private void OnLockKeyChanged(FCk_Handle_KeyLock InLock, FCk_Handle_Item InMaybeKey)
    {
        _KeyChanges += 1;
    }

    // The lock is found and the subject holds the red key from slot 0 on this machine.
    UFUNCTION()
    protected void Is_LockFoundAndKeyHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Ready = Get_IsCarrierReady(_Carrier) && Get_IsLockFound() && Get_SlotHolds(0, mars_items::Key_Red())
            && _Carrier.HeldItem.Get_CurrentItem() == _Carrier.Hotbar.Get_ItemAt(0);
        if (Ready)
        { _Key = _Carrier.Hotbar.Get_ItemAt(0); }

        Result.Set(Ready);
    }

    // The lock holds a key and the subject's hands are empty on this machine.
    UFUNCTION()
    protected void Is_LockHoldingKey(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Ready = Get_IsCarrierReady(_Carrier) && Get_IsLockFound() && ck::IsValid(_Lock.Get_Key())
            && Get_SlotItemCount(0) == 0 && ck::Is_NOT_Valid(_Carrier.HeldItem.Get_CurrentItem());
        if (Ready)
        { _Key = _Lock.Get_Key(); }

        Result.Set(Ready);
    }

    // Server: the key in the subject's hand goes into the lock with a plain Insert (the authority's own caller).
    protected void Insert_ServerKey()
    {
        _Lock.Request_Insert(FMars_Request_KeyLock_Insert(_Key));
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }
}
