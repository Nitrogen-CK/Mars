// What interacting with a cargo slot does: stow the initiator's held item into it, or take its item into the
// initiator's hotbar.
class UMars_SmState_CargoSlot_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_CargoSlot_StowOrTake;
}

// Re-evaluates Get_ActionFor for the initiator, requests the Stow / Take with where the moving item visually is (so its
// next visual lerps from there) and runs until the slot reports the expected content, or that the transfer was refused.
// A Blocked_ action fails with a warning: the prompt processor disables the target for it, but can lag the initiator's
// hands by a frame.
class UMars_SmTask_CargoSlot_StowOrTake : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;
    private FCk_Handle_CargoSlot _Slot;
    private FCk_Handle_Item _Item;
    private EMars_CargoSlot_Action _Action = EMars_CargoSlot_Action::Stow;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Slot = FCk_Handle_CargoSlot();
        _Item = FCk_Handle_Item();

        // The context is the InteractTarget; the initiator is stamped on the per-interaction sub-SM root.
        auto Context = Get_StateMachineContext();
        FCk_Handle SubSm = Get_OwningStateMachine();
        const auto HasContext = Context.Has_Fragment(FMars_Fragment_InteractionContext)
            && ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(HasContext, "[CargoSlot] Interaction ran without an interaction context"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Owner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Initiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        auto Slot = Owner.As_CargoSlot();
        if (ck::Is_NOT_Valid(Slot) || ck::EnsureIfNot(ck::IsValid(Initiator), f"[CargoSlot] [{Slot.ToString()}] interaction has no initiator"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Action = Slot.Get_ActionFor(Initiator);
        if (Action == EMars_CargoSlot_Action::Stow)
        {
            auto HeldItem = Initiator.As_HeldItem();
            auto Item = HeldItem.Get_CurrentItem();
            const auto From = DoGet_WorldOf(HeldItem.Get_PresentationEntity(), HeldItem.Get_HandAttachPoint());

            DoStart(Slot, Item, Action);
            Slot.Request_Stow(FMars_Request_CargoSlot_Stow(Item, From));
            return;
        }

        if (Action == EMars_CargoSlot_Action::Take)
        {
            auto Item = Slot.Get_Item();
            const auto From = DoGet_WorldOf(Slot.Get_Visual(), Slot);
            const auto Target = Initiator.As_Hotbar().TryGet_TakeTarget(Item);

            auto HeldItem = Initiator.As_HeldItem();
            HeldItem.Request_SetNextArrival(FMars_Request_HeldItem_SetNextArrival(Item, From));

            DoStart(Slot, Item, Action);
            Slot.Request_Take(FMars_Request_CargoSlot_Take(Item, Target));
            return;
        }

        DoFail(f"the slot refuses the initiator: [{Action :n}]");
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        return _Outcome;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        DoUnbind();
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
        DoFail(f"the [{_Action :n}] of [{InItem.ToString()}] was refused");
    }

    private void DoStart(FCk_Handle_CargoSlot& InSlot, const FCk_Handle_Item& InItem, EMars_CargoSlot_Action InAction)
    {
        _Slot = InSlot;
        _Item = InItem;
        _Action = InAction;
        _Slot.BindTo_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
        _Slot.BindTo_OnTransferFailed(FMars_Delegate_CargoSlot_OnTransferFailed(this, n"OnSlotTransferFailed"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Slot))
        {
            _Slot.UnbindFrom_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
            _Slot.UnbindFrom_OnTransferFailed(FMars_Delegate_CargoSlot_OnTransferFailed(this, n"OnSlotTransferFailed"));
        }

        _Slot = FCk_Handle_CargoSlot();
    }

    // The world pose of InEntity when it has a transform yet (a pending visual may not), else of InFallback.
    private FTransform DoGet_WorldOf(FCk_Handle InEntity, FCk_Handle InFallback) const
    {
        const auto EntityTransform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(EntityTransform))
        { return utils_transform::Get_EntityCurrentTransform(EntityTransform); }

        return utils_transform::Get_EntityCurrentTransform(InFallback.As_Transform());
    }

    private void DoFail(const FString& InReason)
    {
        ck::Warning(f"[CargoSlot] Interaction failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
    }
}
