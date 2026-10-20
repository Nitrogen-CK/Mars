// What interacting with a hook does: hang the initiator's held lantern, take the hung lantern into the initiator's hotbar,
// or feed it the initiator's held tallow.
class UMars_SmState_LanternHook_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_LanternHook_Interact;
}

// Re-evaluates Get_ActionFor for the initiator and requests the Hang / Take / Refuel. A hang or a take runs until the hook
// reports the expected content, or that the request was refused; a refuel succeeds once requested (the hook ensures and
// keeps the tallow when it refuses). A Blocked_ action fails (ActionBlocked): the prompt processor disables the target for
// it, but can lag the initiator's hands by a frame.
class UMars_SmTask_LanternHook_Interact : UMars_SmTask_InteractionWork
{
    private FCk_Handle_LanternHook _Hook;
    private FCk_Handle_Item _Item;
    private EMars_LanternHook_Action _Action = EMars_LanternHook_Action::Hang;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Hook = FCk_Handle_LanternHook();
        _Item = FCk_Handle_Item();

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        auto Hook = Owner.As_LanternHook(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Hook), f"[LanternHook] Interaction owner [{Owner.ToString()}] is no lantern hook")
            || ck::EnsureIfNot(ck::IsValid(Initiator), f"[LanternHook] [{Hook.ToString()}] interaction has no initiator"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Action = Hook.Get_ActionFor(Initiator);
        if (Action == EMars_LanternHook_Action::Hang)
        {
            auto Item = Initiator.As_HeldItem().Get_CurrentItem();
            DoStart(Hook, Item, Action);
            Hook.Request_Hang(FMars_Request_LanternHook_Hang(Item));
            return;
        }

        if (Action == EMars_LanternHook_Action::Take)
        {
            auto Item = Hook.Get_Item();
            const auto Target = Initiator.As_Hotbar().TryGet_TakeTarget(Item);
            DoStart(Hook, Item, Action);
            Hook.Request_Take(FMars_Request_LanternHook_Take(Item, Target));
            return;
        }

        if (Action == EMars_LanternHook_Action::Refuel)
        {
            Hook.Request_Refuel(FMars_Request_LanternHook_Refuel(Initiator.As_HeldItem().Get_CurrentItem()));
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        DoUnbind();
    }

    UFUNCTION()
    private void OnHookLanternChanged(FCk_Handle_LanternHook InHook, FCk_Handle_Item InMaybeLantern)
    {
        const auto Landed = _Action == EMars_LanternHook_Action::Hang ? InMaybeLantern == _Item : ck::Is_NOT_Valid(InMaybeLantern);
        if (Landed == false)
        { return; }

        DoUnbind();
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    UFUNCTION()
    private void OnHookRequestFailed(FCk_Handle_LanternHook InHook, FCk_Handle_Item InItem)
    {
        if (InItem != _Item)
        { return; }

        DoUnbind();
        DoFail(EMars_Interaction_FailReason::TransferRefused);
    }

    private void DoStart(FCk_Handle_LanternHook& InHook, const FCk_Handle_Item& InItem, EMars_LanternHook_Action InAction)
    {
        _Hook = InHook;
        _Item = InItem;
        _Action = InAction;
        _Hook.BindTo_OnLanternChanged(FMars_Delegate_LanternHook_OnLanternChanged(this, n"OnHookLanternChanged"));
        _Hook.BindTo_OnRequestFailed(FMars_Delegate_LanternHook_OnRequestFailed(this, n"OnHookRequestFailed"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Hook))
        {
            _Hook.UnbindFrom_OnLanternChanged(FMars_Delegate_LanternHook_OnLanternChanged(this, n"OnHookLanternChanged"));
            _Hook.UnbindFrom_OnRequestFailed(FMars_Delegate_LanternHook_OnRequestFailed(this, n"OnHookRequestFailed"));
        }

        _Hook = FCk_Handle_LanternHook();
    }
}
