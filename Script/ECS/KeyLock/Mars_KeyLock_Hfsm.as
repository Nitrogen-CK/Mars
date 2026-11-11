// What interacting with a lock does: insert the initiator's held key, or take the inserted key back into the initiator's
// hotbar.
class UMars_SmState_KeyLock_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_KeyLock_InsertOrTake;
}

// Acts at the Grip of the initiator's gloves on the lock (UMars_SmTask_ActAtGrip: at once without gloves, or when they do
// not reach for it), so the key goes where the hand is: an insert leaves the hand once the glove carrying it closes on the
// keyhole (the key rides that glove there, UMars_Processor_FPHands_Tick's hold follow), a take leaves the keyhole once the
// glove closes on it and rides the glove home (TryGet_RideHome times the held visual's arrival). Re-evaluates
// Get_ActionFor for the initiator at the Grip; an insert first tells this machine's lock where the moving key visually is
// (its next visual lerps from there). The lock moves nothing for the task: utils_key_lock::Request_ActFor asks its
// authority, and the task runs until the effect is visible here or the lock's ledger names this initiator's refusal.
// A Blocked_ action fails (ActionBlocked): the prompt processor disables the target for it, but can lag the initiator's
// hands by a frame.
class UMars_SmTask_KeyLock_InsertOrTake : UMars_SmTask_MoveItemAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_KeyLock _Lock;
    // The key the Act moves, captured at the Grip: the effect is it landing where the action puts it.
    private FCk_Handle_Item _Item;
    private EMars_KeyLock_Action _Action = EMars_KeyLock_Action::Insert;
    // The lock's refusal serial when this task acted: only a later refusal is about it.
    private int32 _RefusalSerialAtAct = 0;

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

    // The lock is asked again: the hands may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        const auto Action = _Lock.Get_ActionFor(_Initiator);
        if (Action == EMars_KeyLock_Action::Insert)
        {
            auto Item = _Initiator.As_HeldItem().Get_CurrentItem();
            _Lock.Request_ExpectArrival(FMars_Request_KeyLock_ExpectArrival(Item, Get_HeldVisualWorld(_Initiator)));
            DoAct(Item, Action);
            return;
        }

        if (Action == EMars_KeyLock_Action::Take)
        {
            auto Item = _Lock.Get_Key();
            Ride_IntoHand(_Initiator, Item, utils_world_item::Get_WorldOf(_Lock.Get_Visual(), _Lock.Get_KeyMount()));
            DoAct(Item, Action);
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
    }

    // An insert lands when the lock holds the key; a take when the lock is empty and the initiator's hotbar holds it.
    protected bool DoGet_EffectLanded() override
    {
        if (ck::Is_NOT_Valid(_Lock))
        { return false; }

        if (_Action == EMars_KeyLock_Action::Insert)
        { return _Lock.Get_Key() == _Item; }

        const auto Hotbar = _Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        return ck::Is_NOT_Valid(_Lock.Get_Key()) && ck::IsValid(Hotbar) && Hotbar.TryGet_SlotIndexOf(_Item).IsSet();
    }

    protected bool DoTryGet_Refusal(EMars_Interaction_FailReason& OutReason) override
    {
        if (ck::Is_NOT_Valid(_Lock) || _Lock.Get_RefusalSerial() <= _RefusalSerialAtAct)
        { return false; }

        if (_Lock.Get_LastRefused() != _Initiator)
        { return false; }

        OutReason = _Lock.Get_LastRefusal();
        return true;
    }

    private void DoAct(const FCk_Handle_Item& InItem, EMars_KeyLock_Action InAction)
    {
        _Item = InItem;
        _Action = InAction;
        _RefusalSerialAtAct = _Lock.Get_RefusalSerial();
        utils_key_lock::Request_ActFor(_Lock, _Initiator, InAction);
        Await_ReplicatedEffect();
    }
}
