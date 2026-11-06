// What interacting with a lock does: insert the initiator's held key, or take the inserted key back into the initiator's
// hotbar.
class UMars_SmState_KeyLock_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_KeyLock_InsertOrTake;
}

// Moves the key at the Grip of the initiator's gloves on the lock (UMars_SmTask_ActAtGrip: at once without gloves, or when
// they do not reach for it), so the key goes where the hand is: an insert leaves the hand once the glove carrying it closes
// on the keyhole (the key rides that glove there, UMars_Processor_FPHands_Tick's hold follow), a take leaves the keyhole
// once the glove closes on it and rides the glove home (TryGet_RideHome times the held visual's arrival). Re-evaluates
// Get_ActionFor for the initiator at the Grip, requests the Insert / Take with where the moving key visually is (so its
// next visual lerps from there) and runs until the lock reports the expected content, or that the transfer was refused.
// A Blocked_ action fails (ActionBlocked): the prompt processor disables the target for it, but can lag the initiator's
// hands by a frame.
class UMars_SmTask_KeyLock_InsertOrTake : UMars_SmTask_MoveItemAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_KeyLock _Lock;
    private FCk_Handle_Item _Item;
    private EMars_KeyLock_Action _Action = EMars_KeyLock_Action::Insert;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Initiator = FCk_Handle();
        _Lock = FCk_Handle_KeyLock();
        _Item = FCk_Handle_Item();

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        auto Lock = Owner.As_KeyLock(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Lock), f"[KeyLock] Interaction owner [{Owner.ToString()}] is no lock")
            || ck::EnsureIfNot(ck::IsValid(Initiator), f"[KeyLock] [{Lock.ToString()}] interaction has no initiator"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Action = Lock.Get_ActionFor(Initiator);
        if (Action != EMars_KeyLock_Action::Insert && Action != EMars_KeyLock_Action::Take)
        {
            DoFail(EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        _Initiator = Initiator;
        _Lock = Lock;
        Await_Grip(Initiator);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        DoUnbind();
    }

    // The lock is asked again: the hands may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        const auto Action = _Lock.Get_ActionFor(_Initiator);
        if (Action == EMars_KeyLock_Action::Insert)
        {
            auto Item = _Initiator.As_HeldItem().Get_CurrentItem();
            DoStart(Item, Action);
            _Lock.Request_Insert(FMars_Request_KeyLock_Insert(Item, Get_HeldVisualWorld(_Initiator)));
            return;
        }

        if (Action == EMars_KeyLock_Action::Take)
        {
            auto Item = _Lock.Get_Key();
            const auto Target = _Initiator.As_Hotbar().TryGet_TakeTarget(Item);
            Ride_IntoHand(_Initiator, Item, utils_world_item::Get_WorldOf(_Lock.Get_Visual(), _Lock.Get_KeyMount()));

            DoStart(Item, Action);
            _Lock.Request_Take(FMars_Request_KeyLock_Take(Item, Target));
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
    }

    UFUNCTION()
    private void OnLockKeyChanged(FCk_Handle_KeyLock InLock, FCk_Handle_Item InMaybeKey)
    {
        const auto Landed = _Action == EMars_KeyLock_Action::Insert ? InMaybeKey == _Item : ck::Is_NOT_Valid(InMaybeKey);
        if (Landed == false)
        { return; }

        DoUnbind();
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    UFUNCTION()
    private void OnLockTransferFailed(FCk_Handle_KeyLock InLock, FCk_Handle_Item InItem)
    {
        if (InItem != _Item)
        { return; }

        DoUnbind();
        DoFail(EMars_Interaction_FailReason::TransferRefused);
    }

    private void DoStart(const FCk_Handle_Item& InItem, EMars_KeyLock_Action InAction)
    {
        _Item = InItem;
        _Action = InAction;
        _Lock.BindTo_OnKeyChanged(FMars_Delegate_KeyLock_OnKeyChanged(this, n"OnLockKeyChanged"));
        _Lock.BindTo_OnTransferFailed(FMars_Delegate_KeyLock_OnTransferFailed(this, n"OnLockTransferFailed"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Lock) && ck::IsValid(_Item))
        {
            _Lock.UnbindFrom_OnKeyChanged(FMars_Delegate_KeyLock_OnKeyChanged(this, n"OnLockKeyChanged"));
            _Lock.UnbindFrom_OnTransferFailed(FMars_Delegate_KeyLock_OnTransferFailed(this, n"OnLockTransferFailed"));
        }

        _Item = FCk_Handle_Item();
    }
}
