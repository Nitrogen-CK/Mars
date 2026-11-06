// What interacting with a cargo slot does: stow the initiator's held item into it, or take its item into the
// initiator's hotbar.
class UMars_SmState_CargoSlot_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_CargoSlot_StowOrTake;
}

// Moves the item at the Grip of the initiator's gloves on the slot (UMars_SmTask_MoveItemAtGrip: at once without gloves,
// or when they do not reach for it): a stow leaves the hand once the glove closes on the slot, a take leaves the slot once
// the glove closes on it and rides the glove home. Re-evaluates Get_ActionFor for the initiator at the Grip, requests the
// Stow / Take with where the moving item visually is (so its next visual lerps from there) and runs until the slot reports
// the expected content, or that the transfer was refused. A Blocked_ action fails (ActionBlocked): the prompt processor
// disables the target for it, but can lag the initiator's hands by a frame. A failure names its reason on the interaction's
// stamped context, which the sub-SM's Failed end reports.
class UMars_SmTask_CargoSlot_StowOrTake : UMars_SmTask_MoveItemAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_CargoSlot _Slot;
    private FCk_Handle_Item _Item;
    private EMars_CargoSlot_Action _Action = EMars_CargoSlot_Action::Stow;

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

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        DoUnbind();
    }

    // The slot is asked again: the hands may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        const auto Action = _Slot.Get_ActionFor(_Initiator);
        if (Action == EMars_CargoSlot_Action::Stow)
        {
            auto Item = _Initiator.As_HeldItem().Get_CurrentItem();
            DoStart(Item, Action);
            _Slot.Request_Stow(FMars_Request_CargoSlot_Stow(Item, Get_HeldVisualWorld(_Initiator)));
            return;
        }

        if (Action == EMars_CargoSlot_Action::Take)
        {
            auto Item = _Slot.Get_Item();
            const auto Target = _Initiator.As_Hotbar().TryGet_TakeTarget(Item);
            Ride_IntoHand(_Initiator, Item, utils_world_item::Get_WorldOf(_Slot.Get_Visual(), _Slot));

            DoStart(Item, Action);
            _Slot.Request_Take(FMars_Request_CargoSlot_Take(Item, Target));
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InMaybeItem)
    {
        const auto Landed = _Action == EMars_CargoSlot_Action::Stow ? InMaybeItem == _Item : ck::Is_NOT_Valid(InMaybeItem);
        if (Landed == false)
        { return; }

        DoUnbind();
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    UFUNCTION()
    private void OnSlotTransferFailed(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InItem)
    {
        if (InItem != _Item)
        { return; }

        DoUnbind();
        DoFail(EMars_Interaction_FailReason::TransferRefused);
    }

    private void DoStart(const FCk_Handle_Item& InItem, EMars_CargoSlot_Action InAction)
    {
        _Item = InItem;
        _Action = InAction;
        _Slot.BindTo_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
        _Slot.BindTo_OnTransferFailed(FMars_Delegate_CargoSlot_OnTransferFailed(this, n"OnSlotTransferFailed"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Slot) && ck::IsValid(_Item))
        {
            _Slot.UnbindFrom_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
            _Slot.UnbindFrom_OnTransferFailed(FMars_Delegate_CargoSlot_OnTransferFailed(this, n"OnSlotTransferFailed"));
        }

        _Item = FCk_Handle_Item();
    }
}
