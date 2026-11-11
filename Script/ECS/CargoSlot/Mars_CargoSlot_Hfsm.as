// What interacting with a cargo slot does: stow the initiator's held item into it, or take its item into the
// initiator's hotbar.
class UMars_SmState_CargoSlot_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_CargoSlot_StowOrTake;
}

// Acts at the Grip of the initiator's gloves on the slot (UMars_SmTask_MoveItemAtGrip: at once without gloves, or when
// they do not reach for it): a stow leaves the hand once the glove closes on the slot, a take leaves the slot once the
// glove closes on it and rides the glove home. Re-evaluates Get_ActionFor for the initiator at the Grip; a stow first tells
// this machine's slot where the moving item visually is (its next cargo visual lerps from there). The slot moves nothing
// for the task: utils_cargo_slot::Request_ActFor asks its authority, and the task runs until the effect is visible here or
// the slot's ledger names this initiator's refusal. A Blocked_ action fails (ActionBlocked): the prompt processor disables
// the target for it, but can lag the initiator's hands by a frame.
class UMars_SmTask_CargoSlot_StowOrTake : UMars_SmTask_MoveItemAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_CargoSlot _Slot;
    // The item the Act moves, captured at the Grip: the effect is it landing where the action puts it.
    private FCk_Handle_Item _Item;
    private EMars_CargoSlot_Action _Action = EMars_CargoSlot_Action::Stow;
    // The slot's refusal serial when this task acted: only a later refusal is about it.
    private int32 _RefusalSerialAtAct = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Initiator = FCk_Handle();
        _Slot = FCk_Handle_CargoSlot();
        _Item = FCk_Handle_Item();

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        auto Slot = Owner.As_CargoSlot(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Slot), f"[CargoSlot] Interaction owner [{Owner.ToString()}] is no cargo slot")
            || ck::EnsureIfNot(ck::IsValid(Initiator), f"[CargoSlot] [{Slot.ToString()}] interaction has no initiator"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Action = Slot.Get_ActionFor(Initiator);
        if (Action != EMars_CargoSlot_Action::Stow && Action != EMars_CargoSlot_Action::Take)
        {
            DoFail(EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        _Initiator = Initiator;
        _Slot = Slot;
        Await_Grip(Initiator);
    }

    // The slot is asked again: the hands may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        const auto Action = _Slot.Get_ActionFor(_Initiator);
        if (Action == EMars_CargoSlot_Action::Stow)
        {
            auto Item = _Initiator.As_HeldItem().Get_CurrentItem();
            _Slot.Request_ExpectArrival(FMars_Request_CargoSlot_ExpectArrival(Item, Get_HeldVisualWorld(_Initiator)));
            DoAct(Item, Action);
            return;
        }

        if (Action == EMars_CargoSlot_Action::Take)
        {
            auto Item = _Slot.Get_Item();
            Ride_IntoHand(_Initiator, Item, utils_world_item::Get_WorldOf(_Slot.Get_Visual(), _Slot));
            DoAct(Item, Action);
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
    }

    // A stow lands when the slot holds the item; a take when the slot is empty and the initiator's hotbar holds it.
    protected bool DoGet_EffectLanded() override
    {
        if (ck::Is_NOT_Valid(_Slot))
        { return false; }

        if (_Action == EMars_CargoSlot_Action::Stow)
        { return _Slot.Get_Item() == _Item; }

        const auto Hotbar = _Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        return _Slot.Get_IsOccupied() == false && ck::IsValid(Hotbar) && Hotbar.TryGet_SlotIndexOf(_Item).IsSet();
    }

    protected bool DoTryGet_Refusal(EMars_Interaction_FailReason& OutReason) override
    {
        if (ck::Is_NOT_Valid(_Slot) || _Slot.Get_RefusalSerial() <= _RefusalSerialAtAct)
        { return false; }

        if (_Slot.Get_LastRefused() != _Initiator)
        { return false; }

        OutReason = _Slot.Get_LastRefusal();
        return true;
    }

    private void DoAct(const FCk_Handle_Item& InItem, EMars_CargoSlot_Action InAction)
    {
        _Item = InItem;
        _Action = InAction;
        _RefusalSerialAtAct = _Slot.Get_RefusalSerial();
        utils_cargo_slot::Request_ActFor(_Slot, _Initiator, InAction);
        Await_ReplicatedEffect();
    }
}
