// What interacting with a lock does: insert the initiator's held key, or take the inserted key back into the initiator's
// hotbar.
class UMars_SmState_KeyLock_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_KeyLock_InsertOrTake;
}

// Re-evaluates Get_ActionFor for the initiator, requests the Insert / Take with where the moving key visually is (so its
// next visual lerps from there) and runs until the lock reports the expected content, or that the transfer was refused.
// A Blocked_ action fails (ActionBlocked): the prompt processor disables the target for it, but can lag the initiator's
// hands by a frame.
class UMars_SmTask_KeyLock_InsertOrTake : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;
    private FCk_Handle_KeyLock _Lock;
    private FCk_Handle_Item _Item;
    private EMars_KeyLock_Action _Action = EMars_KeyLock_Action::Insert;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Lock = FCk_Handle_KeyLock();
        _Item = FCk_Handle_Item();

        // The context is the InteractTarget; the initiator is stamped on the per-interaction sub-SM root.
        auto Context = Get_StateMachineContext();
        FCk_Handle SubSm = Get_OwningStateMachine();
        const auto HasContext = Context.Has_Fragment(FMars_Fragment_InteractionContext)
            && ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(HasContext, "[KeyLock] Interaction ran without an interaction context"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Owner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Initiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        auto Lock = Owner.As_KeyLock(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Lock), f"[KeyLock] Interaction owner [{Owner.ToString()}] is no lock")
            || ck::EnsureIfNot(ck::IsValid(Initiator), f"[KeyLock] [{Lock.ToString()}] interaction has no initiator"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Action = Lock.Get_ActionFor(Initiator);
        if (Action == EMars_KeyLock_Action::Insert)
        {
            auto HeldItem = Initiator.As_HeldItem();
            auto Item = HeldItem.Get_CurrentItem();
            const auto From = DoGet_WorldOf(HeldItem.Get_PresentationEntity(), HeldItem.Get_HandAttachPoint());

            DoStart(Lock, Item, Action);
            Lock.Request_Insert(FMars_Request_KeyLock_Insert(Item, From));
            return;
        }

        if (Action == EMars_KeyLock_Action::Take)
        {
            auto Item = Lock.Get_Key();
            const auto From = DoGet_WorldOf(Lock.Get_Visual(), Lock.Get_KeyMount());
            const auto Target = Initiator.As_Hotbar().TryGet_TakeTarget(Item);

            auto HeldItem = Initiator.As_HeldItem();
            HeldItem.Request_SetNextArrival(FMars_Request_HeldItem_SetNextArrival(Item, From));

            DoStart(Lock, Item, Action);
            Lock.Request_Take(FMars_Request_KeyLock_Take(Item, Target));
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
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

    private void DoStart(FCk_Handle_KeyLock& InLock, const FCk_Handle_Item& InItem, EMars_KeyLock_Action InAction)
    {
        _Lock = InLock;
        _Item = InItem;
        _Action = InAction;
        _Lock.BindTo_OnKeyChanged(FMars_Delegate_KeyLock_OnKeyChanged(this, n"OnLockKeyChanged"));
        _Lock.BindTo_OnTransferFailed(FMars_Delegate_KeyLock_OnTransferFailed(this, n"OnLockTransferFailed"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Lock))
        {
            _Lock.UnbindFrom_OnKeyChanged(FMars_Delegate_KeyLock_OnKeyChanged(this, n"OnLockKeyChanged"));
            _Lock.UnbindFrom_OnTransferFailed(FMars_Delegate_KeyLock_OnTransferFailed(this, n"OnLockTransferFailed"));
        }

        _Lock = FCk_Handle_KeyLock();
    }

    // The world pose of InEntity when it has a transform yet (a pending visual may not), else of InFallback.
    private FTransform DoGet_WorldOf(FCk_Handle InEntity, FCk_Handle InFallback) const
    {
        const auto EntityTransform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(EntityTransform))
        { return utils_transform::Get_EntityCurrentTransform(EntityTransform); }

        return utils_transform::Get_EntityCurrentTransform(InFallback.As_Transform());
    }

    private void DoFail(EMars_Interaction_FailReason InReason)
    {
        utils_interactable::Record_FailReason(Get_OwningStateMachine(), InReason);
        _Outcome = ECk_SmTaskResult::Failed;
    }
}
